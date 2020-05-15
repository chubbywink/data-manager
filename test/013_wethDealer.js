const Vat = artifacts.require('Vat');
const Pot = artifacts.require('Pot');
const Lender = artifacts.require('Lender');
const YDai = artifacts.require('YDai');
const ERC20 = artifacts.require('TestERC20');
const GemJoin = artifacts.require('GemJoin');
const DaiJoin = artifacts.require('DaiJoin');
const WethOracle = artifacts.require('WethOracle');
const WethDealer = artifacts.require('WethDealer');

const truffleAssert = require('truffle-assertions');

contract('WethDealer', async (accounts) =>  {
    let [ owner, user ] = accounts;
    let vat;
    let pot;
    let lender;
    let yDai;
    let weth;
    let wethJoin;
    let dai;
    let daiJoin;
    let wethOracle;
    let wethDealer;
    let maturity;
    let ilk = web3.utils.fromAscii("ETH-A")
    let Line = web3.utils.fromAscii("Line")
    let spotName = web3.utils.fromAscii("spot")
    let linel = web3.utils.fromAscii("line")
    const RAD = web3.utils.toBN('49')
    const limits =  web3.utils.toBN('10').pow(RAD).toString();
    const spot  = "1500000000000000000000000000";
    const rate  = "1250000000000000000000000000";
    const price  = "1200000000000000000000000000"; // spot / rate
    const daiTokens = web3.utils.toWei("125");  // Dai we borrow
    const daiDebt = web3.utils.toWei("100");    // Dai debt for `frob`: daiTokens / rate = 100
    const wethTokens = web3.utils.toWei("150"); // Collateral we join: daiTokens * price = 125


    beforeEach(async() => {
        // Set up vat, join and weth
        vat = await Vat.new();
        await vat.rely(vat.address, { from: owner });

        weth = await ERC20.new(0, { from: owner }); 
        await vat.init(ilk, { from: owner }); // Set ilk rate to 1.0
        wethJoin = await GemJoin.new(vat.address, ilk, weth.address, { from: owner });
        await vat.rely(wethJoin.address, { from: owner });

        dai = await ERC20.new(0, { from: owner });
        daiJoin = await DaiJoin.new(vat.address, dai.address, { from: owner });
        await vat.rely(daiJoin.address, { from: owner });

        // Setup vat
        await vat.file(ilk, spotName, spot, { from: owner });
        await vat.file(ilk, linel, limits, { from: owner });
        await vat.file(Line, limits); // TODO: Why can't we specify `, { from: owner }`?
        const rateIncrease  = "250000000000000000000000000";
        await vat.fold(ilk, vat.address, rateIncrease, { from: owner }); // 1 + 0.25

        // Setup pot
        pot = await Pot.new(vat.address);
        await vat.rely(pot.address, { from: owner });

        // Set lender
        lender = await Lender.new(
            dai.address,        // dai
            weth.address,       // weth
            daiJoin.address,    // daiJoin
            wethJoin.address,   // wethJoin
            vat.address,        // vat
        );
        await vat.rely(lender.address, { from: owner }); //?

        // Setup yDai
        const block = await web3.eth.getBlockNumber();
        maturity = (await web3.eth.getBlock(block)).timestamp + 1000;
        yDai = await YDai.new(vat.address, pot.address, maturity, "Name", "Symbol");

        // Setup WethOracle
        wethOracle = await WethOracle.new(vat.address, { from: owner });

        // Setup WethDealer
        wethDealer = await WethDealer.new(
            lender.address,
            yDai.address,
            weth.address,
            wethOracle.address,
            { from: owner },
        );
        await yDai.grantAccess(wethDealer.address, { from: owner });
        await lender.grantAccess(wethDealer.address, { from: owner });
    });

    it("retrieves weth price as rate / spot", async() => {
        assert.equal(
            await wethOracle.price.call({ from: owner }), // price() is a transaction
            price,
            "Should be " + price,
        );
    });

    it("allows user to post weth", async() => {
        await weth.mint(owner, wethTokens, { from: owner });
        assert.equal(
            (await weth.balanceOf(owner)),   
            wethTokens,
            "ERC20Dealer does not have weth",
        );
        assert.equal(
            (await vat.urns(ilk, lender.address)).ink.toString(),   
            0,
            "Lender has weth in MakerDAO",
        );
        assert.equal(
            (await wethDealer.unlockedOf.call(owner)),   
            0,
            "Owner has unlocked weth",
        );
        
        await weth.approve(wethDealer.address, wethTokens, { from: owner }); 
        await wethDealer.post(owner, wethTokens, { from: owner });

        assert.equal(
            (await vat.urns(ilk, lender.address)).ink.toString(),   
            wethTokens,
            "Lender should have weth in MakerDAO",
        );
        assert.equal(
            (await wethDealer.unlockedOf.call(owner)),   
            wethTokens,
            "Owner should have unlocked collateral",
        );
        assert.equal(
            (await weth.balanceOf(owner)),   
            0,
            "Owner should not have weth",
        );
    });

    describe("with posted weth", () => {
        beforeEach(async() => {
            await weth.mint(owner, wethTokens, { from: owner });
            await weth.approve(wethDealer.address, wethTokens, { from: owner }); 
            await wethDealer.post(owner, wethTokens, { from: owner });
        });

        it("allows user to withdraw weth", async() => {
            assert.equal(
                (await vat.urns(ilk, lender.address)).ink.toString(),   
                wethTokens,
                "Lender does not have weth in MakerDAO",
            );
            assert.equal(
                (await weth.balanceOf(owner)),   
                0,
                "Owner has weth",
            );
            assert.equal(
                (await wethDealer.unlockedOf.call(owner)),   
                wethTokens,
                "Owner does not have unlocked weth",
            );

            await wethDealer.withdraw(owner, wethTokens, { from: owner });

            assert.equal(
                (await weth.balanceOf(owner)),   
                wethTokens,
                "Owner should have weth",
            );
            assert.equal(
                (await vat.urns(ilk, lender.address)).ink.toString(),   
                0,
                "Lender should not have weth in MakerDAO",
            );
            assert.equal(
                (await wethDealer.unlockedOf.call(owner)),   
                0,
                "Owner should have unlocked weth",
            );
        });

        it("allows to borrow yDai", async() => {
            assert.equal(
                (await wethDealer.unlockedOf.call(owner)),   
                wethTokens,
                "Owner does not have unlocked collateral",
            );
            assert.equal(
                (await yDai.balanceOf(owner)),   
                0,
                "Owner has yDai",
            );
            assert.equal(
                (await wethDealer.debtOf.call(owner)),   
                0,
                "Owner has debt",
            );
    
            await wethDealer.borrow(owner, daiTokens, { from: owner });

            assert.equal(
                (await yDai.balanceOf(owner)),   
                daiTokens,
                "Owner should have yDai",
            );
            assert.equal(
                (await wethDealer.debtOf.call(owner)),   
                daiTokens,
                "Owner should have debt",
            );
            assert.equal(
                (await wethDealer.unlockedOf.call(owner)),   
                0,
                "Owner should not have unlocked collateral",
            );
        });

        describe("with borrowed yDai", () => {
            beforeEach(async() => {
                await wethDealer.borrow(owner, daiTokens, { from: owner });
            });

            it("allows to repay yDai", async() => {
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    daiTokens,
                    "Owner does not have yDai",
                );
                assert.equal(
                    (await wethDealer.debtOf.call(owner)),   
                    daiTokens,
                    "Owner does not have debt",
                );
                assert.equal(
                    (await wethDealer.unlockedOf.call(owner)),   
                    0,
                    "Owner has unlocked collateral",
                );

                await yDai.approve(wethDealer.address, daiTokens, { from: owner });
                await wethDealer.repay(owner, daiTokens, { from: owner });
    
                assert.equal(
                    (await wethDealer.unlockedOf.call(owner)),   
                    wethTokens,
                    "Owner should have unlocked collateral",
                );
                assert.equal(
                    (await yDai.balanceOf(owner)),   
                    0,
                    "Owner should not have yDai",
                );
                assert.equal(
                    (await wethDealer.debtOf.call(owner)),   
                    0,
                    "Owner should not have debt",
                );
            });
        });
    });
});