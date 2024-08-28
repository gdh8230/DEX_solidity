// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Dex {
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    mapping(bytes32 => Token) public tokens;
    bytes32[] public tokenList;

    function addToken(bytes32 ticker, address tokenAddress) public {
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }
}