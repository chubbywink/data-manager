import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'

import { Cauldron } from '../typechain/Cauldron'
import { Ladle } from '../typechain/Ladle'
import { Join } from '../typechain/Join'
import { Witch } from '../typechain/Witch'
import { FYToken } from '../typechain/FYToken'
import { ERC20Mock } from '../typechain/ERC20Mock'
import { OracleMock } from '../typechain/OracleMock'

import { ethers, waffle } from 'hardhat'
import { expect } from 'chai'
const { deployContract, loadFixture } = waffle
const timeMachine = require('ether-time-traveler')

import { YieldEnvironment, WAD, RAY, THREE_MONTHS } from './shared/fixtures'

describe('Witch', () => {
  let snapshotId: any
  let env: YieldEnvironment
  let ownerAcc: SignerWithAddress
  let otherAcc: SignerWithAddress
  let owner: string
  let other: string
  let cauldron: Cauldron
  let ladle: Ladle
  let witch: Witch
  let witchFromOther: Witch
  let fyToken: FYToken
  let base: ERC20Mock
  let ilk: ERC20Mock
  let ilkJoin: Join
  let spotOracle: OracleMock
  let rateOracle: OracleMock

  const mockAssetId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const mockVaultId = ethers.utils.hexlify(ethers.utils.randomBytes(12))
  const MAX = ethers.constants.MaxUint256

  async function fixture() {
    return await YieldEnvironment.setup(ownerAcc, [baseId, ilkId], [seriesId])
  }

  before(async () => {
    snapshotId = await timeMachine.takeSnapshot(ethers.provider) // `loadFixture` messes up with the chain state, so we revert to a clean state after each test file.
    const signers = await ethers.getSigners()
    ownerAcc = signers[0]
    owner = await ownerAcc.getAddress()

    otherAcc = signers[1]
    other = await otherAcc.getAddress()
  })

  after(async () => {
    await timeMachine.revertToSnapshot(ethers.provider, snapshotId) // Once all tests are done, revert the chain
  })

  const baseId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const ilkId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const seriesId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  let vaultId: string

  beforeEach(async () => {
    env = await loadFixture(fixture)
    cauldron = env.cauldron
    ladle = env.ladle
    witch = env.witch
    base = env.assets.get(baseId) as ERC20Mock
    ilk = env.assets.get(ilkId) as ERC20Mock
    ilkJoin = env.joins.get(ilkId) as Join
    fyToken = env.series.get(seriesId) as FYToken
    rateOracle = env.oracles.get(baseId) as OracleMock
    spotOracle = env.oracles.get(ilkId) as OracleMock

    witchFromOther = witch.connect(otherAcc)

    vaultId = (env.vaults.get(seriesId) as Map<string, string>).get(ilkId) as string
    ladle.pour(vaultId, WAD, WAD)
  })

  it('does not allow to grab collateralized vaults', async () => {
    await expect(witch.grab(vaultId)).to.be.revertedWith('Not undercollateralized')
  })

  it('does not allow to grab uninitialized vaults', async () => {
    await expect(witch.grab(mockVaultId)).to.be.revertedWith('Vault not found')
  })

  it('does not allow to buy from uninitialized vaults', async () => {
    await expect(witch.buy(mockVaultId, 0, 0)).to.be.revertedWith('Nothing to buy')
  })

  it('grabs undercollateralized vaults', async () => {
    await spotOracle.setSpot(RAY.div(2))
    await witch.grab(vaultId)
    const event = (await cauldron.queryFilter(cauldron.filters.VaultTimestamped(null, null)))[0]
    expect(event.args.timestamp.toNumber()).to.be.greaterThan(0)
    expect(await cauldron.timestamps(vaultId)).to.equal(event.args.timestamp)
  })

  describe('once a vault has been grabbed', async () => {
    beforeEach(async () => {
      await spotOracle.setSpot(RAY.div(2))
      await witch.grab(vaultId)
    })

    it("it can't be grabbed again", async () => {
      await expect(witch.grab(vaultId)).to.be.revertedWith('Timestamped')
    })

    it('does not buy if minimum collateral not reached', async () => {
      await expect(witch.buy(vaultId, WAD, WAD)).to.be.revertedWith('Not enough bought')
    })

    it('allows to buy 1/2 of the collateral for the whole debt at the beginning', async () => {
      const baseBalanceBefore = await base.balanceOf(owner)
      const ilkBalanceBefore = await ilk.balanceOf(owner)
      // await expect(witch.buy(vaultId, WAD, 0)).to.emit(witch, 'Bought').withArgs(owner, vaultId, null, WAD)
      await witch.buy(vaultId, WAD, 0)
      // const event = (await witch.queryFilter(witch.filters.Bought(null, null, null, null)))[0]
      const ink = WAD.sub((await cauldron.balances(vaultId)).ink)
      expect(ink.div(10 ** 15)).to.equal(WAD.div(10 ** 15).div(2)) // Nice hack to compare up to some precision
      expect(await base.balanceOf(owner)).to.equal(baseBalanceBefore.sub(WAD))
      expect(await ilk.balanceOf(owner)).to.equal(ilkBalanceBefore.add(ink))
    })

    describe('once the auction time has passed', async () => {
      beforeEach(async () => {
        await timeMachine.advanceTimeAndBlock(ethers.provider, (await witch.AUCTION_TIME()).toNumber())
      })

      it('allows to buy all of the collateral for the whole debt at the end', async () => {
        const baseBalanceBefore = await base.balanceOf(owner)
        const ilkBalanceBefore = await ilk.balanceOf(owner)
        // await expect(witch.buy(vaultId, WAD, 0)).to.emit(witch, 'Bought').withArgs(owner, vaultId, null, WAD)
        await witch.buy(vaultId, WAD, 0)
        // const event = (await witch.queryFilter(witch.filters.Bought(null, null, null, null)))[0]
        const ink = WAD.sub((await cauldron.balances(vaultId)).ink)
        expect(ink).to.equal(WAD)
        expect(await base.balanceOf(owner)).to.equal(baseBalanceBefore.sub(WAD))
        expect(await ilk.balanceOf(owner)).to.equal(ilkBalanceBefore.add(ink))
      })
    })
  })
})
