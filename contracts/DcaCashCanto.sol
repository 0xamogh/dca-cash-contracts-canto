// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./TimedAllowance.sol";
import "./lib/LibERC20Token.sol";
import "./interfaces/IRouter.sol";

contract DcaCashCanto is Ownable {
    using LibERC20Token for IERC20;
    using SafeMath for uint256;

    IRouter public constant swapRouter =
        IRouter(0xa252eEE9BDe830Ca4793F054B506587027825a8e);
    TimedAllowance public timedAllowance;
    address public constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(bytes => address) public taskIdOwners;
    uint256 public recurringFee;

    constructor() {
        timedAllowance = new TimedAllowance();

        // Fee is 0.1% by default
        recurringFee = 1;
    }

    function executeSwap(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 resetTime
    ) public onlyOwner {
        //check if task exists and is valid
        bytes memory id = abi.encode(user, address(this),tokenIn, tokenOut, amountIn, resetTime);

        require(taskIdOwners[id] != address(0), "DcaCash : Invalid user");
        require(
            taskIdOwners[id] == user,
            "DcaCash : Task does not exist or is not valid"
        );

        // Transfer tokens in from user
        timedAllowance.transferFrom(id);

        // Pay dev x%
        if (recurringFee > 0) {
            uint256 fee = SafeMath.mul(recurringFee, amountIn);
            fee = SafeMath.div(fee, 1000);
            payDevFee(tokenIn, fee);
            amountIn = SafeMath.sub(amountIn, fee);
        }

        // LibERC20Token (approve if below)
        LibERC20Token.approveIfBelow(tokenIn, address(swapRouter), amountIn);

        // Allow for 5% slippage
        (uint256 quote, bool stable) = swapRouter.getAmountOut(
            amountIn,
            tokenIn,
            tokenOut
        );
        quote = SafeMath.mul(quote, 95);
        quote = SafeMath.div(quote, 100);

        // Execute swap
        swapRouter.swapExactTokensForTokensSimple(
            amountIn,
            quote,
            tokenIn,
            tokenOut,
            stable,
            user,
            block.timestamp
        );
    }

    function swapBatcher(
        address[] calldata user,
        address[] calldata tokenIn,
        address[] calldata tokenOut,
        uint256[] calldata amountIn,
        uint256[] calldata resetTime
    ) external onlyOwner {
        require(
            user.length == tokenIn.length &&
                user.length == tokenOut.length &&
                user.length == amountIn.length &&
                user.length == resetTime.length,
            "DcaCash : Invalid input"
        );
        for (uint256 i = 0; i < user.length; i++) {
            executeSwap(
                user[i],
                tokenIn[i],
                tokenOut[i],
                amountIn[i],
                resetTime[i]
            );
        }
    }

    function createTask(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 resetTime
    ) public payable returns (bytes memory) {
        bytes memory id = abi.encode(_msgSender(), address(this), tokenIn, tokenOut, amount, resetTime);
        
        timedAllowance.approve(id);
        
        (uint256 readAmount, , ) = timedAllowance.orderAllowances(id);
        require(
            readAmount > 0 && readAmount == amount,
            "DcaCash : Please set a valid amount"
        );


        taskIdOwners[id] = _msgSender();
        return id;
    }

    function cancelTask(bytes memory id) external {
        require(
            taskIdOwners[id] == _msgSender(),
            "DcaCash : You do not own this task"
        );
        timedAllowance.revokeApproval(id);
        taskIdOwners[id] = address(0);
    }

    function setRecurringFee(uint256 amount) external onlyOwner {
        recurringFee = amount;
    }

    function payDevFee(address token, uint256 amount) public onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
