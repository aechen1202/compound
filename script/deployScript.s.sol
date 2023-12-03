// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Comp} from "../src/Governance/Comp.sol";
import {Comptroller} from "../src/Comptroller.sol";
import {Unitroller} from "../src/Unitroller.sol";
import {CErc20} from "../src/CErc20.sol";
import {CErc20Delegate} from "../src/CErc20Delegate.sol";
import {CErc20Delegator} from "../src/CErc20Delegator.sol";
import {WhitePaperInterestRateModel} from "../src/WhitePaperInterestRateModel.sol";
import {SimplePriceOracle} from "../src/SimplePriceOracle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract deployScript is Script {
    function setUp() public {}
    
    //forge script script/deployScript.s.sol:deployScript --rpc-url https://eth-sepolia.g.alchemy.com/v2/chdu1oHs8eln1C0_vtOOXA2P8_mpvk5C --broadcast --verify --etherscan-api-key HRQM484S3IBPF5RKFWI4Y2DINNU6F6TZTY

    function run() public {
        address admin=0xF5Bfbe59812B3f174387074C40b266dC8590fad9;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        
        //InterestRateModel
        WhitePaperInterestRateModel whitePaperInterestRateModel = new WhitePaperInterestRateModel(0,0);

        //PriceOracle
        SimplePriceOracle priceOracle = new SimplePriceOracle();

        //comp token
        Comp comp = new Comp(admin);

        //Comptroller
        Comptroller comptroller = new Comptroller();
        Unitroller unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        Comptroller unitrollerProxy = Comptroller(address(unitroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        //token
        erc20Token token =new erc20Token("artToken","art");
        CErc20Delegate cErc20Delegate = new CErc20Delegate();

        CErc20Delegator cErc20Delegator = new CErc20Delegator(
            address(token),
            comptroller,
            whitePaperInterestRateModel,
            1,
            "cArt",
            "cArt",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
    }
    
}

contract erc20Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}
