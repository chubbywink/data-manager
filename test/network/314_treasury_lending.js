const Migrations = artifacts.require('Migrations');
const Vat = artifacts.require("Vat");
const Weth = artifacts.require("WETH9");
const ERC20 = artifacts.require("TestERC20");
const GemJoin = artifacts.require("GemJoin");
const DaiJoin = artifacts.require("DaiJoin");
const Jug = artifacts.require("Jug");
const Pot = artifacts.require("Pot");
const Chai = artifacts.require("Chai");
const GasToken = artifacts.require("GasToken1");
const WethOracle = artifacts.require("WethOracle");
const ChaiOracle = artifacts.require("ChaiOracle");
const Treasury = artifacts.require("Treasury");
const Dealer = artifacts.require("Dealer");

const truffleAssert = require('truffle-assertions');
const { expectRevert } = require('@openzeppelin/test-helpers');
const { toWad, toRay, toRad, addBN, subBN, mulRay, divRay } = require('../shared/utils');

contract('Treasury - Lending', async (accounts) =>  {
    let [ owner, user ] = accounts;

    let vat;
    let weth;
    let wethJoin;
    let dai;
    let daiJoin;
    let jug;
    let pot;
    let chai;
    let gasToken;
    let wethOracle;
    let chaiOracle;
    let treasury;
    let dealer;

    let ilk = web3.utils.fromAscii('ETH-A');
    let spot;
    let rate;
    let chi;
    
    let wethTokens;
    let daiTokens;
    let daiDebt;
    let chaiTokens;

    beforeEach(async() => {
        const migrations = await Migrations.deployed();

        vat = await Vat.at(await migrations.contracts(web3.utils.fromAscii("Vat")));
        weth = await Weth.at(await migrations.contracts(web3.utils.fromAscii("Weth")));
        wethJoin = await GemJoin.at(await migrations.contracts(web3.utils.fromAscii("WethJoin")));
        dai = await ERC20.at(await migrations.contracts(web3.utils.fromAscii("Dai")));
        daiJoin = await DaiJoin.at(await migrations.contracts(web3.utils.fromAscii("DaiJoin")));
        jug = await Jug.at(await migrations.contracts(web3.utils.fromAscii("Jug")));
        pot = await Pot.at(await migrations.contracts(web3.utils.fromAscii("Pot")));
        chai = await Chai.at(await migrations.contracts(web3.utils.fromAscii("Chai")));
        gasToken = await GasToken.at(await migrations.contracts(web3.utils.fromAscii("GasToken")));
        treasury = await Treasury.at(await migrations.contracts(web3.utils.fromAscii("Treasury")));
        
        spot  = (await vat.ilks(ilk)).spot;
        rate  = (await vat.ilks(ilk)).rate;
        chi = await pot.chi(); // Good boys call drip()

        wethTokens = toWad(1);
        daiTokens = mulRay(wethTokens.toString(), spot.toString());
        daiDebt = divRay(daiTokens.toString(), rate.toString());
        chaiTokens = divRay(daiTokens, chi.toString());
        
        await treasury.grantAccess(owner, { from: owner });
        await vat.hope(daiJoin.address, { from: owner });
    });

    it("allows to post collateral", async() => {
        assert.equal(
            (await weth.balanceOf(wethJoin.address)),
            web3.utils.toWei("0")
        );
        
        await weth.deposit({ from: user, value: wethTokens});
        await weth.transfer(treasury.address, wethTokens, { from: user }); 
        await treasury.pushWeth({ from: owner });

        // Test transfer of collateral
        assert.equal(
            await weth.balanceOf(wethJoin.address),
            wethTokens.toString(),
        );

        // Test collateral registering via `frob`
        assert.equal(
            (await vat.urns(ilk, treasury.address)).ink,
            wethTokens.toString(),
        );
    });

    it("pulls dai borrowed from MakerDAO for user", async() => {
        // Test with two different stability rates, if possible.
        await treasury.pullDai(user, daiTokens, { from: owner });

        assert.equal(
            await dai.balanceOf(user),
            daiTokens.toString(),
        );
        assert.equal(
            (await vat.urns(ilk, treasury.address)).art,
            daiDebt.toString(),
        );
    });

    it("pushes dai that repays debt towards MakerDAO", async() => {
        // Test `normalizedAmount >= normalizedDebt`
        //await dai.approve(treasury.address, daiTokens, { from: user });
        dai.transfer(treasury.address, daiTokens, { from: user }); // We can't stop donations
        await treasury.pushDai({ from: owner });

        assert.equal(
            await dai.balanceOf(user),
            0
        );
        assert.equal(
            (await vat.urns(ilk, treasury.address)).art,
            0,
        );
        assert.equal(
            await vat.dai(treasury.address),
            0
        );
    });

    it("pulls chai converted from dai borrowed from MakerDAO for user", async() => {
        await treasury.pullChai(user, chaiTokens, { from: owner });

        assert.equal(
            await chai.balanceOf(user),
            chaiTokens.toString(),
        );
        assert.equal(
            (await vat.urns(ilk, treasury.address)).art,
            daiDebt.toString(),
        );
    });

    it("pushes chai that repays debt towards MakerDAO", async() => {
        await chai.transfer(treasury.address, chaiTokens, { from: user }); 
        await treasury.pushChai({ from: owner });

        assert.equal(
            await dai.balanceOf(user),
            0
        );
        assert.equal(
            (await vat.urns(ilk, treasury.address)).art,
            0,
        );
        assert.equal(
            await vat.dai(treasury.address),
            0
        );
    });

    it("allows to withdraw collateral", async() => {
        assert.equal(
            await weth.balanceOf(owner),
            0,
        );
        
        await treasury.pullWeth(owner, wethTokens, { from: owner });

        // Test transfer of collateral
        assert.equal(
            (await weth.balanceOf(owner)),
            wethTokens.toString(),
        );

        // Test collateral registering via `frob`
        assert.equal(
            (await vat.urns(ilk, treasury.address)).ink,
            0
        );

        // Restore state
        await weth.withdraw(wethTokens, { from: owner });
    });
});