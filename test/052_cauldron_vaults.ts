import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'

import { Cauldron } from '../typechain/Cauldron'
import { Ladle } from '../typechain/Ladle'
import { FYToken } from '../typechain/FYToken'
import { ERC20Mock } from '../typechain/ERC20Mock'

import { YieldEnvironment, WAD } from './shared/fixtures'

import { ethers, waffle } from 'hardhat'
import { expect } from 'chai'
const { loadFixture } = waffle

describe('Cauldron - Vaults', () => {
  let ownerAcc: SignerWithAddress
  let owner: string
  let otherAcc: SignerWithAddress
  let other: string
  let env: YieldEnvironment
  let cauldron: Cauldron
  let ladle: Ladle
  let cauldronFromOther: Cauldron
  let fyToken: FYToken
  let base: ERC20Mock
  let ilk: ERC20Mock

  const baseId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const ilkId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const otherIlkId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const seriesId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const otherSeriesId = ethers.utils.hexlify(ethers.utils.randomBytes(6))

  const mockAssetId = ethers.utils.hexlify(ethers.utils.randomBytes(6))
  const emptyAssetId = '0x000000000000'
  const mockAddress = ethers.utils.getAddress(ethers.utils.hexlify(ethers.utils.randomBytes(20)))
  const emptyAddress = ethers.utils.getAddress('0x0000000000000000000000000000000000000000')

  async function fixture() {
    return await YieldEnvironment.setup(ownerAcc, [baseId, ilkId, otherIlkId], [seriesId, otherSeriesId])
  }

  before(async () => {
    const signers = await ethers.getSigners()
    ownerAcc = signers[0]
    owner = await ownerAcc.getAddress()

    otherAcc = signers[1]
    other = await otherAcc.getAddress()
  })

  beforeEach(async () => {
    env = await loadFixture(fixture)
    cauldron = env.cauldron
    ladle = env.ladle
    base = env.assets.get(baseId) as ERC20Mock
    ilk = env.assets.get(ilkId) as ERC20Mock
    fyToken = env.series.get(seriesId) as FYToken

    cauldronFromOther = cauldron.connect(otherAcc)
  })

  it('does not build a vault with an unknown series', async () => {
    // TODO: Error message misleading, replace in contract for something generic
    await expect(cauldron.build(mockAssetId, ilkId)).to.be.revertedWith('Ilk not added')
  })

  it('does not build a vault with an unknown ilk', async () => {
    // TODO: Might be removed, redundant with approved ilk check
    await expect(cauldron.build(seriesId, mockAssetId)).to.be.revertedWith('Ilk not added')
  })

  it('does not build a vault with an ilk that is not approved for a series', async () => {
    await cauldron.addAsset(mockAssetId, mockAddress)
    await expect(cauldron.build(seriesId, mockAssetId)).to.be.revertedWith('Ilk not added')
  })

  it('builds a vault', async () => {
    // expect(await cauldron.build(seriesId, mockIlks)).to.emit(cauldron, 'VaultBuilt').withArgs(null, seriesId, mockIlks);
    await cauldron.build(seriesId, ilkId)
    const event = (await cauldron.queryFilter(cauldron.filters.VaultBuilt(null, null, null, null)))[0]
    const vaultId = event.args.vaultId
    const vault = await cauldron.vaults(vaultId)
    expect(vault.owner).to.equal(owner)
    expect(vault.seriesId).to.equal(seriesId)
    expect(vault.ilkId).to.equal(ilkId)

    // Remove these two when `expect...to.emit` works
    expect(event.args.owner).to.equal(owner)
    expect(event.args.seriesId).to.equal(seriesId)
    expect(event.args.ilkId).to.equal(ilkId)
  })

  describe('with a vault built', async () => {
    let vaultId: string

    beforeEach(async () => {
      await cauldron.build(seriesId, ilkId)
      const event = (await cauldron.queryFilter(cauldron.filters.VaultBuilt(null, null, null, null)))[0]
      vaultId = event.args.vaultId
    })

    it('does not allow destroying vaults if not the vault owner', async () => {
      await expect(cauldronFromOther.destroy(vaultId)).to.be.revertedWith('Only vault owner')
    })

    it('does not allow destroying vaults if not empty', async () => {
      await ladle.stir(vaultId, WAD, 0)
      await expect(cauldron.destroy(vaultId)).to.be.revertedWith('Only empty vaults')
    })

    it('destroys a vault', async () => {
      expect(await cauldron.destroy(vaultId))
        .to.emit(cauldron, 'VaultDestroyed')
        .withArgs(vaultId)
      const vault = await cauldron.vaults(vaultId)
      expect(vault.owner).to.equal(emptyAddress)
      expect(vault.seriesId).to.equal(emptyAssetId)
      expect(vault.ilkId).to.equal(emptyAssetId)
    })

    it('does not allow changing vaults if not the vault owner', async () => {
      await expect(cauldronFromOther.tweak(vaultId, seriesId, ilkId)).to.be.revertedWith('Only vault owner')
    })

    it('does not allow changing vaults to non-approved collaterals', async () => {
      await expect(cauldron.tweak(vaultId, seriesId, mockAssetId)).to.be.revertedWith('Ilk not added')
    })

    it('does not allow changing vaults with debt', async () => {
      await ladle.stir(vaultId, WAD, WAD)
      await expect(cauldron.tweak(vaultId, otherSeriesId, otherIlkId)).to.be.revertedWith('Only with no debt')
    })

    it('does not allow changing vaults with collateral', async () => {
      await ladle.stir(vaultId, WAD, 0)
      await expect(cauldron.tweak(vaultId, seriesId, otherIlkId)).to.be.revertedWith('Only with no collateral')
    })

    it('changes a vault', async () => {
      expect(await cauldron.tweak(vaultId, otherSeriesId, otherIlkId))
        .to.emit(cauldron, 'VaultTweaked')
        .withArgs(vaultId, otherSeriesId, otherIlkId)
      const vault = await cauldron.vaults(vaultId)
      expect(vault.owner).to.equal(owner)
      expect(vault.seriesId).to.equal(otherSeriesId)
      expect(vault.ilkId).to.equal(otherIlkId)
    })

    it('does not allow giving vaults if not the vault owner', async () => {
      await expect(cauldronFromOther.give(vaultId, other)).to.be.revertedWith('Only vault owner')
    })

    it('gives a vault', async () => {
      expect(await cauldron.give(vaultId, other))
        .to.emit(cauldron, 'VaultTransfer')
        .withArgs(vaultId, other)
      const vault = await cauldron.vaults(vaultId)
      expect(vault.owner).to.equal(other)
      expect(vault.seriesId).to.equal(seriesId)
      expect(vault.ilkId).to.equal(ilkId)
    })
  })
})
