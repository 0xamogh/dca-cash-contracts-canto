// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TimedAllowance is Ownable {
    using SafeERC20 for IERC20;

    struct ApprovalInfo {
        uint256 amount;
        uint256 resetTime;
        uint256 lastReset;
    }

    mapping(bytes => ApprovalInfo) public orderAllowances;
    function approve(bytes memory id) public {
        (,,address tokenIn,,uint256 amount, uint256 resetTime) = abi.decode(id, (address,address,address,address,uint256,uint256));
        require(IERC20(tokenIn).allowance(tx.origin, address(this)) > 0, "TimedAllowance : Please approve ERC20 first");
        
        // using tx origin ensures that nobody apart from the actual signer can modify their orderAllowances
        orderAllowances[id] = ApprovalInfo({
            amount : amount,
            resetTime: resetTime,
            lastReset : 0
        });
    }

    function transferFrom(bytes memory id) public onlyOwner {
        (address from, address to,address tokenIn,,uint256 amount,) = abi.decode(id, (address,address,address,address,uint256,uint256));
        require(orderAllowances[id].amount > 0,"TimedAllowance : Amount not set");
        require(block.timestamp - orderAllowances[id].lastReset >= orderAllowances[id].resetTime,"TimedAllowance : Reset time has not elapsed yet, try again later");
        require(orderAllowances[id].amount >= amount,"TimedAllowance : Not enough allowance");

        orderAllowances[id].lastReset = block.timestamp;
        IERC20(tokenIn).safeTransferFrom(from, to, amount);
    }

    function revokeApproval(bytes memory id) public onlyOwner {
        orderAllowances[id] = ApprovalInfo({
            amount : 0,
            resetTime: type(uint256).max,
            lastReset : type(uint256).max
        });
    }
}