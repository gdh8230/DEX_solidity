// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Dex is ERC20 {
    address public tokenX;
    address public tokenY;

    uint112 public reserveX;
    uint112 public reserveY;

    constructor(address _tokenX, address _tokenY) ERC20("Upside", "UP") {
        tokenX = _tokenX;
        tokenY = _tokenY;
    }

    function addLiquidity(uint256 _amountX, uint256 _amountY, uint256 _minimumLP) external returns (uint256) {
        require(IERC20(tokenX).allowance(msg.sender, address(this)) >= _amountX, "ERC20: insufficient allowance");
        require(IERC20(tokenY).allowance(msg.sender, address(this)) >= _amountY, "ERC20: insufficient allowance");
        require(IERC20(tokenX).balanceOf(msg.sender) >= _amountX, "ERC20: transfer amount exceeds balance");
        require(IERC20(tokenY).balanceOf(msg.sender) >= _amountY, "ERC20: transfer amount exceeds balance");

        IERC20(tokenX).transferFrom(msg.sender, address(this), _amountX);
        IERC20(tokenY).transferFrom(msg.sender, address(this), _amountY);

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        uint256 amountX = balanceX - reserveX;
        uint256 amountY = balanceY - reserveY;

        uint256 totalLP = totalSupply();
        uint256 liquidity;

        if (totalLP == 0) {
            liquidity = Math.sqrt(amountX * amountY);
        } else {
            uint256 shareX = (amountX * totalLP) / reserveX;
            uint256 shareY = (amountY * totalLP) / reserveY;
            liquidity = Math.min(shareX, shareY);
        }

        require(liquidity > _minimumLP, "Insufficient liquidity minted");

        reserveX = uint112(balanceX);
        reserveY = uint112(balanceY);
        _mint(msg.sender, liquidity);

        return liquidity;
    }

    function removeLiquidity(uint256 _amountLP, uint256 _minAmountX, uint256 _minAmountY) external returns (uint256, uint256) {
        require(_amountLP > 0, "Insufficient LP amount");

        uint256 totalLP = totalSupply();

        uint256 amountX = (reserveX * _amountLP) / totalLP;
        uint256 amountY = (reserveY * _amountLP) / totalLP;

        require(amountX >= _minAmountX && amountY >= _minAmountY, "Insufficient token amount");

        _burn(msg.sender, _amountLP);

        reserveX -= uint112(amountX);
        reserveY -= uint112(amountY);

        IERC20(tokenX).transfer(msg.sender, amountX);
        IERC20(tokenY).transfer(msg.sender, amountY);

        return (amountX, amountY);
    }

    function swap(uint256 _amountX, uint256 _amountY, uint256 _minOutput) external returns (uint256) {
        require((_amountX > 0 && _amountY == 0) || (_amountX == 0 && _amountY > 0), "Invalid input: specify only one input amount");

        uint256 inputAmount;
        uint256 outputAmount;
        address inputToken;
        address outputToken;
        uint112 reserveIn;
        uint112 reserveOut;

        if (_amountX > 0) {
            inputAmount = _amountX;
            inputToken = tokenX;
            outputToken = tokenY;
            reserveIn = reserveX;
            reserveOut = reserveY;
        } else {
            inputAmount = _amountY;
            inputToken = tokenY;
            outputToken = tokenX;
            reserveIn = reserveY;
            reserveOut = reserveX;
        }

        uint256 inputAmountWithFee = inputAmount * 999 / 1000; // Apply a 0.1% fee
        outputAmount = (inputAmountWithFee * reserveOut) / (reserveIn + inputAmountWithFee);

        require(outputAmount >= _minOutput, "Insufficient output amount");

        IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);
        IERC20(outputToken).transfer(msg.sender, outputAmount);

        // Update reserves
        if (_amountX > 0) {
            reserveX += uint112(inputAmount);
            reserveY -= uint112(outputAmount);
        } else {
            reserveY += uint112(inputAmount);
            reserveX -= uint112(outputAmount);
        }

        return outputAmount;
    }
}
