pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import {
  IFlashLoanSimpleReceiver,
  IPoolAddressesProvider,
  IPool
} from "./interfaces/IFlashLoanSimpleReceiver.sol";
import {CErc20Interface,CTokenInterface} from "../CTokenInterfaces.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {CErc20Delegator} from "../CErc20Delegator.sol";

// TODO: Inherit IFlashLoanSimpleReceiver
contract AaveFlashLoan {

  address admin;
  address constant uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
  struct CompoundData { 
   address borrower;
   uint cRepayAmount;
   address cTokenCBorrow;
   address cTokenCollateral;
   address underlyTokenCollateral;
   address aavePool;
  }

  constructor(address _admin){
    admin = _admin;
  }
 
  
 function execute(uint256 aaveAmount,uint cRepayAmount, address aaveAsset,address aavePool
    , address cTokenCBorrow , address cTokenCollateral, address underlyTokenCollateral ,address borrower) external {
    // TODO

    //組參數
    CompoundData memory compoundData;
    compoundData.borrower=borrower;
    compoundData.cTokenCBorrow =cTokenCBorrow;
    compoundData.cTokenCollateral =cTokenCollateral;
    compoundData.aavePool=aavePool;
    compoundData.cRepayAmount=cRepayAmount;
    compoundData.underlyTokenCollateral = underlyTokenCollateral;
    bytes memory params = abi.encode(compoundData);
    
    //aave flashLoan
    POOL(aavePool).flashLoanSimple(address(this), aaveAsset, aaveAmount, params, 0);
  }

  //aave call back
  function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params) external returns (bool) {
    CompoundData memory compoundData = abi.decode(params,(CompoundData));
    
    //compound liquidateBorrow
    IERC20(asset).approve(compoundData.cTokenCBorrow, IERC20(asset).balanceOf(address(this)));
    CErc20Interface(compoundData.cTokenCBorrow).liquidateBorrow(compoundData.borrower,  compoundData.cRepayAmount, CTokenInterface(compoundData.cTokenCollateral));
    CErc20Interface(compoundData.cTokenCollateral).redeem(CTokenInterface(compoundData.cTokenCollateral).balanceOf(address(this)));
    
    //uniswap UNI tp USDC
    uint swapAmount=IERC20(compoundData.underlyTokenCollateral).balanceOf(address(this));
    IERC20(compoundData.underlyTokenCollateral).approve(uniswapV3Router,swapAmount);
    ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: compoundData.underlyTokenCollateral,
            tokenOut: asset,
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: swapAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
    ISwapRouter(uniswapV3Router).exactInputSingle(swapParams);

    //approve aave pool using usdc to pay back loan
    IERC20(asset).approve(address(POOL(compoundData.aavePool)), amount + premium);
    return true;
}

  function ADDRESSES_PROVIDER(address pool) public view returns (IPoolAddressesProvider) {
    return IPoolAddressesProvider(pool);
  }

  function POOL(address pool) public view returns (IPool) {
    return IPool(ADDRESSES_PROVIDER(pool).getPool());
  }
  
  function withdraw(address token) external {
      require(msg.sender == admin,"only owner call");
      IERC20(token).transfer(admin, IERC20(token).balanceOf(address(this)));
  }
}
