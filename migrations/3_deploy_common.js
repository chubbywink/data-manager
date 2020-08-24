const { id } = require('ethers/lib/utils')
const fixed_addrs = require('./fixed_addrs.json');
const Migrations = artifacts.require("Migrations");
const Vat = artifacts.require("Vat");
const GemJoin = artifacts.require("GemJoin");
const DaiJoin = artifacts.require("DaiJoin");
const Pot = artifacts.require("Pot");
const End = artifacts.require("End");
const Chai = artifacts.require("Chai");
const Treasury = artifacts.require("Treasury");
const Controller = artifacts.require("Controller");
const Unwind = artifacts.require("Unwind");
const Liquidations = artifacts.require("Liquidations");
const Weth = artifacts.require("WETH9");
const ERC20 = artifacts.require("TestERC20");

module.exports = async (deployer, network, accounts) => {
  const migrations = await Migrations.deployed();
  
  let vatAddress;
  let wethAddress;
  let wethJoinAddress;
  let daiAddress;
  let daiJoinAddress;
  let potAddress;
  let endAddress;
  let chaiAddress;
  let treasuryAddress;
  let controllerAddress;
  let unwindAddress;
  let liquidationsAddress;

  if (network !== 'development') {
    vatAddress = fixed_addrs[network].vatAddress ;
    wethAddress = fixed_addrs[network].wethAddress;
    wethJoinAddress = fixed_addrs[network].wethJoinAddress;
    daiAddress = fixed_addrs[network].daiAddress;
    daiJoinAddress = fixed_addrs[network].daiJoinAddress;
    potAddress = fixed_addrs[network].potAddress;
    endAddress = fixed_addrs[network].endAddress;
    fixed_addrs[network].chaiAddress ? 
      (chaiAddress = fixed_addrs[network].chaiAddress)
      : (chaiAddress = (await Chai.deployed()).address);
 } else {
    vatAddress = (await Vat.deployed()).address;
    wethAddress = (await Weth.deployed()).address;
    wethJoinAddress = (await GemJoin.deployed()).address;
    daiAddress = (await ERC20.deployed()).address;
    daiJoinAddress = (await DaiJoin.deployed()).address;
    potAddress = (await Pot.deployed()).address;
    endAddress = (await End.deployed()).address;
    chaiAddress = (await Chai.deployed()).address;
 }

  // Setup treasury
  await deployer.deploy(
    Treasury,
    vatAddress,
    wethAddress,
    daiAddress,
    wethJoinAddress,
    daiJoinAddress,
    potAddress,
    chaiAddress,
  );
  treasury = await Treasury.deployed();
  treasuryAddress = treasury.address;

  // Setup controller
  await deployer.deploy(
    Controller,
    vatAddress,
    potAddress,
    treasuryAddress,
  );
  const controller = await Controller.deployed();
  controllerAddress = controller.address;
  const treasuryFunctions = ['pushDai', 'pullDai', 'pushChai', 'pullChai', 'pushWeth', 'pullWeth'].map(func => id(func + '(address,uint256)'))
  await treasury.batchOrchestrate(controllerAddress, treasuryFunctions)

  // Setup Liquidations
  await deployer.deploy(
    Liquidations,
    treasuryAddress,
    controllerAddress,
  )
  const liquidations = await Liquidations.deployed()
  liquidationsAddress = liquidations.address;
  await controller.orchestrate(liquidationsAddress, id('erase(bytes32,address)'))
  await treasury.orchestrate(liquidationsAddress, id('erase(address)'));

  // Setup Unwind
  await deployer.deploy(
    Unwind,
    vatAddress,
    daiJoinAddress,
    wethAddress,
    wethJoinAddress,
    potAddress,
    endAddress,
    chaiAddress,
    treasuryAddress,
    controllerAddress,
    liquidationsAddress,
  );
  const unwind = await Unwind.deployed();
  unwindAddress = unwind.address;
  await controller.orchestrate(unwind.address, id('erase(bytes32,address)'))
  await liquidations.orchestrate(unwind.address, id('erase(address)'))
  await treasury.registerUnwind(unwindAddress);

  // Commit addresses to migrations registry
  const deployedCore = {
    'Treasury': treasuryAddress,
    'Controller': controllerAddress,
    'Unwind': unwindAddress,
    'Liquidations': liquidationsAddress,
  }

  for (name in deployedCore) {
    await migrations.register(web3.utils.fromAscii(name), deployedCore[name]);
  }
  console.log(deployedCore)
};
