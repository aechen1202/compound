// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
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

contract CounterTest is Test {
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comp public comp;
    Comptroller public unitrollerProxy;
    WhitePaperInterestRateModel public whitePaperInterestRateModel;
    ERC20 public token;
    CErc20Delegate public cErc20Delegate;
    CErc20Delegator public cErc20Delegator;
    SimplePriceOracle public simplePriceOracle;
    SimplePriceOracle public priceOracle;
    address public admin = makeAddr("admin");
   
    function setUp() public {
        vm.startPrank(admin);

        //InterestRateModel
        whitePaperInterestRateModel=new WhitePaperInterestRateModel(0,0);

        //PriceOracle
        priceOracle = new SimplePriceOracle();

        //comp token
        comp = new Comp(admin);

        //Comptroller
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        unitrollerProxy = Comptroller(address(unitroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        //token
        token =new erc20Token("artToken","art");
        cErc20Delegate = new CErc20Delegate();

        cErc20Delegator = new CErc20Delegator(
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

    function test_comp() public {
        console.log(address(comp));
        console.log(address(comptroller));
    }
}

contract erc20Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}