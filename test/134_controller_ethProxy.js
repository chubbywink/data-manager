// Peripheral
const EthProxy = artifacts.require('EthProxy');

const helper = require('ganache-time-traveler');
const { balance } = require('@openzeppelin/test-helpers');
const { WETH, daiTokens1, wethTokens1 } = require('./shared/utils');
const { YieldEnvironmentLite } = require("./shared/fixtures");

contract('Controller - EthProxy', async (accounts) =>  {
    let [ owner, user ] = accounts;

    let snapshot;
    let snapshotId;

    let maturity1;
    let maturity2;

    beforeEach(async() => {
        snapshot = await helper.takeSnapshot();
        snapshotId = snapshot['result'];

        const yield = await YieldEnvironmentLite.setup();
        maker = yield.maker;
        controller = yield.controller;
        treasury = yield.treasury;
        pot = yield.maker.pot;
        vat = yield.maker.vat;
        dai = yield.maker.dai;
        chai = yield.maker.chai;
        weth = yield.maker.weth;

        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity1 = (await web3.eth.getBlock(block)).timestamp + 1000;
        maturity2 = (await web3.eth.getBlock(block)).timestamp + 2000;
        yDai1 = await yield.newYDai(maturity1, "Name", "Symbol");
        yDai2 = await yield.newYDai(maturity2, "Name", "Symbol");

        // Setup EthProxy
        ethProxy = await EthProxy.new(
            weth.address,
            treasury.address,
            controller.address,
            { from: owner },
        );
        await controller.addDelegate(ethProxy.address, { from: owner });
    });

    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

    it("allows user to post eth", async() => {
        assert.equal(
            (await vat.urns(WETH, treasury.address)).ink,
            0,
            "Treasury has weth in MakerDAO",
        );
        assert.equal(
            await controller.powerOf(WETH, owner),
            0,
            "Owner has borrowing power",
        );
        
        const previousBalance = await balance.current(owner);
        await ethProxy.post(wethTokens1, { from: owner, value: wethTokens1 });

        expect(await balance.current(owner)).to.be.bignumber.lt(previousBalance);
        assert.equal(
            (await vat.urns(WETH, treasury.address)).ink,
            wethTokens1.toString(),
            "Treasury should have weth in MakerDAO",
        );
        assert.equal(
            await controller.powerOf(WETH, owner),
            daiTokens1.toString(),
            "Owner should have " + daiTokens1 + " borrowing power, instead has " + await controller.powerOf(WETH, owner),
        );
    });

    describe("with posted eth", () => {
        beforeEach(async() => {
            await ethProxy.post(wethTokens1, { from: owner, value: wethTokens1 });

            assert.equal(
                (await vat.urns(WETH, treasury.address)).ink,
                wethTokens1.toString(),
                "Treasury does not have weth in MakerDAO",
            );
            assert.equal(
                await controller.powerOf(WETH, owner),
                daiTokens1.toString(),
                "Owner does not have borrowing power",
            );
            assert.equal(
                await weth.balanceOf(owner),
                0,
                "Owner has collateral in hand"
            );
            assert.equal(
                await yDai1.balanceOf(owner),
                0,
                "Owner has yDai",
            );
            assert.equal(
                await controller.debtDai(WETH, maturity1, owner),
                0,
                "Owner has debt",
            );
        });

        it("allows user to withdraw weth", async() => {
            const previousBalance = await balance.current(owner);
            await ethProxy.withdraw(wethTokens1, { from: owner });

            expect(await balance.current(owner)).to.be.bignumber.gt(previousBalance);
            assert.equal(
                (await vat.urns(WETH, treasury.address)).ink,
                0,
                "Treasury should not not have weth in MakerDAO",
            );
            assert.equal(
                await controller.powerOf(WETH, owner),
                0,
                "Owner should not have borrowing power",
            );
        });
    });
});
