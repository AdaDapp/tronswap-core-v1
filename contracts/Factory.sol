pragma solidity >=0.4.0 <0.7.0;

import "./Exchange.sol";

// todo:
// 1. token logo url
contract Factory {
    uint256 public tokenCount;
    mapping(address => address) public tokenToExchange;
    mapping(address => address) public exchangeToToken;
    mapping(uint256 => address) public idToToken;
  
    function createExchange(address token) public returns (address) {
        require(token != address(0), "token cann't be zero address");
        require(tokenToExchange[token] == address(0), "this token exchange has existed");
        address exchange = new Exchange(token);
        tokenToExchange[token] = exchange;
        exchangeToToken[exchange] = token;
        uint256 tokenId = tokenCount + 1;
        tokenCount = tokenId;
        idToToken[tokenId] = token;
        // log.NewExchange(token, exchange)
        return exchange;
    }
}
