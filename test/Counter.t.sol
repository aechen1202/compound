// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Comp} from "../src/Governance/Comp.sol";
import {Comptroller} from "../src/Comptroller.sol";
import {Unitroller} from "../src/Unitroller.sol";
import {WhitePaperInterestRateModel} from "../src/WhitePaperInterestRateModel.sol";
import "forge-std/console.sol";

contract CounterTest is Test {
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comp public comp;
    Comptroller public unitrollerProxy;
    WhitePaperInterestRateModel public whitePaperInterestRateModel;
    address public admin = makeAddr("admin");
   
    function setUp() public {
        vm.startPrank(admin);
        comp = new Comp(admin);
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        unitrollerProxy = Comptroller(address(unitroller));
        comptroller._become(unitroller);
        whitePaperInterestRateModel=new WhitePaperInterestRateModel(100,100);
    }

    function test_getReserve() public {
        console.log(address(comp));
        console.log(address(comptroller));
    }
}
