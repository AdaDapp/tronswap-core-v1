pragma solidity >=0.4.0 <0.7.0;

import "./Factory.sol";
import "./ERC20.sol";
import "./TronswapERC20.sol";

// todo:
// 1. safe SafeMath
// 2. modify comment
// 3. check public or not
contract Exchange is TronswapERC20 {
    
    // using SafeMath for uint256;
    
    Factory public factory;
    ERC20 public exchangeToken;

    constructor(address _exchangeToken) public {
        factory = Factory(msg.sender);
        // in factory, check if equal to tronswaptoken or not
        // todo: super?
        exchangeToken = ERC20(_exchangeToken);
    }
    
    // todo safemath
    // @notice Deposit ETH and Tokens (self.token) at current ratio to mint UNI tokens.
    // @dev min_liquidity does nothing when total UNI supply is 0.
    // @param min_liquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
    // @param max_tokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
    // @param deadline Time after which this transaction can no longer be executed.
    // @return The amount of UNI minted.
    // todo: when constructor, call case when == 0
    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) public payable returns (uint256) {
        require(block.timestamp < deadline, "block.timestamp beyond deadline");
        require(msg.value > 0, "msg.value should be greater than 0");
        uint256 totalLiquidity = totalSupply;  // use this.totalSupply ?
        if (totalLiquidity > 0) {
            require(minLiquidity > 0, "minLiquidity should be greater than 0");
            uint256 baseAdded = msg.value;
            uint256 baseReserve = address(this).balance - msg.value;
            uint256 tokenReserve = exchangeToken.balanceOf(address(this));
            uint256 needTokenAmount = tokenReserve * msg.value / baseReserve + 1;
            uint256 LiquidityAdded = totalLiquidity * msg.value / baseReserve;
            require(maxTokens >= needTokenAmount && LiquidityAdded >= minLiquidity,
                "maxTokens should be greater than needTokenAmount, or LiquidityAdded should be greater than minLiquidity");
            
            balances[msg.sender] += LiquidityAdded;
            totalSupply = totalLiquidity + LiquidityAdded;
            require(exchangeToken.transferFrom(msg.sender, address(this), needTokenAmount), "transfer exchange token fail");
            
            // todo log
            // log.AddLiquidity(msg.sender, msg.value, token_amount)
            // log.Transfer(ZERO_ADDRESS, msg.sender, liquidity_minted)
            return LiquidityAdded;
        } else {
            require(maxTokens > 0, "maxTokens should be greater than 0");
            require(msg.value >= 1000000000, "msg.value should be greater than or equal to 1000000000");
            uint256 needTokenAmount = maxTokens;
            totalSupply = address(this).balance; // use this.totalSupply ?
            balances[msg.sender] = totalSupply; // use this.balances ?
            // todo: usdt have no return !!!
            require(exchangeToken.transferFrom(msg.sender, address(this), needTokenAmount), "transfer exchange token fail");
            
            // todo log
            // log.AddLiquidity(msg.sender, msg.value, token_amount)
            // log.Transfer(ZERO_ADDRESS, msg.sender, initial_liquidity)
            return totalSupply;
        }
    }
    
    // @dev Burn UNI tokens to withdraw ETH and Tokens at current ratio.
    // @param amount Amount of UNI burned.
    // @param min_eth Minimum ETH withdrawn.
    // @param min_tokens Minimum Tokens withdrawn.
    // @param deadline Time after which this transaction can no longer be executed.
    // @return The amount of ETH and Tokens withdrawn.
    function removeLiquidity(uint256 remove, uint256 minBase, uint256 minTokens, uint256 deadline) public returns (uint256, uint256) {
        require(block.timestamp < deadline, "block.timestamp beyond deadline");
        require(remove > 0 && minBase > 0 && minTokens > 0, "remove, minBase, minTokens should be greater than 0");
        uint256 totalLiquidity = totalSupply;
        require(totalLiquidity > 0, "totalLiquidity should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 removeBase = address(this).balance * remove / totalLiquidity;
        uint256 removeToken = tokenReserve * remove / totalLiquidity;
        require(removeBase >= minBase && removeToken >= minTokens,
            "removeBase should be greater than or equal to minBase, or, removeToken should be greater than or equal to minTokens");
        balances[msg.sender] -= remove;
        totalSupply = totalLiquidity - remove;
        require(msg.sender.send(removeBase), "send to msg.sender fail");
        // todo: usdt have no return !!!
        require(exchangeToken.transfer(msg.sender, removeToken), "transfer exchange token to msg.sender fail");
        
        // todo log
        // log.RemoveLiquidity(msg.sender, eth_amount, token_amount)
        // log.Transfer(msg.sender, ZERO_ADDRESS, amount)
        return (removeBase, removeToken);
    }
    
    function baseToTokenInput(uint256 baseSold, uint256 minTokens, uint256 deadline, address buyer, address recipient) private returns (uint256) {
        require(block.timestamp <= deadline, "block.timestamp beyond deadline");
        require(baseSold > 0 && minTokens > 0, "baseSold, minTokens should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 tokensBought = getInputPrice(baseSold, address(this).balance - baseSold, tokenReserve);
        require(tokensBought >= minTokens, "tokensBought should be greater than or equal to minTokens");
        // todo: usdt have no return !!!
        require(exchangeToken.transfer(recipient, tokensBought), "transfer exchange token fail");
        // todo log
        // log.TokenPurchase(buyer, eth_sold, tokens_bought)
        return tokensBought;
    }
    
    // @notice Convert ETH to Tokens.
    // @dev User specifies exact input (msg.value).
    // @dev User cannot specify minimum output or deadline.
    function() payable public {
        baseToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }
     
    // @notice Convert ETH to Tokens.
    // @dev User specifies exact input (msg.value) and minimum output.
    // @param min_tokens Minimum Tokens bought.
    // @param deadline Time after which this transaction can no longer be executed.
    // @return Amount of Tokens bought.
    function baseToTokenSwapInput(uint256 minTokens, uint256 deadline) payable public returns (uint256) {
        return baseToTokenInput(msg.value, minTokens, deadline, msg.sender, msg.sender);
    }
    
    // @notice Convert ETH to Tokens and transfers Tokens to recipient.
    // @dev User specifies exact input (msg.value) and minimum output
    // @param min_tokens Minimum Tokens bought.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output Tokens.
    // @return Amount of Tokens bought.
    function baseToTokenTransferInput(uint256 minTokens, uint256 deadline, address recipient) payable public returns (uint256) {
        require(recipient != address(this) && recipient != address(0), "recipient cann't be this self or zero address");
        return baseToTokenInput(msg.value, minTokens, deadline, msg.sender, recipient);
    }
    
    function baseToTokenOutput(uint256 tokensBought, uint256 maxBase, uint256 deadline, address buyer, address recipient) private returns (uint256) {
        require(block.timestamp <= deadline, "block.timestamp beyond deadline");
        require(tokensBought > 0 && maxBase > 0, "tokensBought, maxBase should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 baseSold = getOutputPrice(tokensBought, address(this).balance - maxBase, tokenReserve);
        require(baseSold <= maxBase, "baseSold should be less than or equal to maxBase");
        if (baseSold < maxBase) {
            require(buyer.send(maxBase - baseSold), "send to buyer fail");
        }
        // todo: usdt have no return !!!
        require(exchangeToken.transfer(recipient, tokensBought), "transfer exchange token fail");
        // todo log
        // log.TokenPurchase(buyer, as_wei_value(eth_sold, 'wei'), tokens_bought)
        return baseSold;
    }
    
    // @notice Convert ETH to Tokens.
    // @dev User specifies maximum input (msg.value) and exact output.
    // @param tokens_bought Amount of tokens bought.
    // @param deadline Time after which this transaction can no longer be executed.
    // @return Amount of ETH sold.
    function baseToTokenSwapOutput(uint256 tokensBought, uint256 deadline) public payable returns (uint256) {
        return baseToTokenOutput(tokensBought, msg.value, deadline, msg.sender, msg.sender);
    }
    
    // @notice Convert ETH to Tokens and transfers Tokens to recipient.
    // @dev User specifies maximum input (msg.value) and exact output.
    // @param tokens_bought Amount of tokens bought.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output Tokens.
    // @return Amount of ETH sold.
    function baseToTokenTransferOutput(uint256 tokensBought, uint256 deadline, address recipient) public payable returns(uint256) {
        require(recipient != address(this) && recipient != address(0), "recipient cann't be this self or zero address");
        return baseToTokenOutput(tokensBought, msg.value, deadline, msg.sender, recipient);
    }
    
    function tokenToBaseInput(uint256 tokensSold, uint256 minBase, uint256 deadline, address buyer, address recipient) private returns (uint256) {
        require(block.timestamp <= deadline, "block.timestamp beyond deadline");
        require(tokensSold > 0 && minBase > 0, "tokensSold, minBase should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 baseBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        require(baseBought >= minBase, "baseBought should be greater than or equal to minBase");
        require(recipient.send(baseBought), "send to recipient fail");
        // todo: usdt have no return !!!
        require(exchangeToken.transferFrom(buyer, address(this), tokensSold), "transfer exchange token fail");
        // todo log
        // log.EthPurchase(buyer, tokens_sold, wei_bought)
        return baseBought;
    }
    
    // @notice Convert Tokens to ETH.
    // @dev User specifies exact input and minimum output.
    // @param tokens_sold Amount of Tokens sold.
    // @param min_eth Minimum ETH purchased.
    // @param deadline Time after which this transaction can no longer be executed.
    // @return Amount of ETH bought.
    function tokenToBaseSwapInput(uint256 tokensSold, uint256 minBase, uint256 deadline) public returns (uint256) {
        return tokenToBaseInput(tokensSold, minBase, deadline, msg.sender, msg.sender);
    }
    
    // @notice Convert Tokens to ETH and transfers ETH to recipient.
    // @dev User specifies exact input and minimum output.
    // @param tokens_sold Amount of Tokens sold.
    // @param min_eth Minimum ETH purchased.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output ETH.
    // @return Amount of ETH bought.
    function tokenToBaseTransferInput(uint256 tokensSold, uint256 minBase, uint256 deadline, address recipient) public returns (uint256) {
        require(recipient != address(this) && recipient != address(0), "recipient cann't be this self or zero address");
        return tokenToBaseInput(tokens_sold, min_eth, deadline, msg.sender, recipient);
    }
    
    function tokenToBaseOutput(uint256 baseBought, uint256 maxTokens, uint256 deadline, address buyer, address recipient) private returns (uint256) {
        require(block.timestamp <= deadline, "block.timestamp beyond deadline");
        require(baseBought > 0 && maxTokens > 0, "baseBought, maxTokens should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(baseBought, tokenReserve, address(this).balance);
        require(tokensSold <= maxTokens, "tokensSold should be less than or equal to maxTokens");
        require(recipient.send(baseBought), "send to recipient fail");
        // todo: usdt have no return !!!
        require(exchangeToken.transferFrom(buyer, address(this), tokensSold), "transfer exchange token fail");
        // todo log
        // log.EthPurchase(buyer, tokens_sold, eth_bought)
        return tokensSold;
    }
    
    // @notice Convert Tokens to ETH.
    // @dev User specifies maximum input and exact output.
    // @param eth_bought Amount of ETH purchased.
    // @param max_tokens Maximum Tokens sold.
    // @param deadline Time after which this transaction can no longer be executed.
    // @return Amount of Tokens sold.
    function tokenToBaseSwapOutput(uint256 basebought, uint256 maxTokens, uint256 deadline) public returns (uint256) {
        return tokenToBaseOutput(basebought, maxTokens, deadline, msg.sender, msg.sender);
    }
    
    // @notice Convert Tokens to ETH and transfers ETH to recipient.
    // @dev User specifies maximum input and exact output.
    // @param eth_bought Amount of ETH purchased.
    // @param max_tokens Maximum Tokens sold.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output ETH.
    // @return Amount of Tokens sold.
    function tokenToBaseTransferOutput(uint256 basebought, uint256 maxTokens, uint256 deadline, address recipient) public returns (uint256) {
        require(recipient != address(this) && recipient != address(0), "recipient cann't be this self or zero address");
        return tokenToBaseOutput(basebought, maxTokens, deadline, msg.sender, recipient);
    }
    
    function tokenToTokenInput(uint256 tokensSold, uint256 minTokensBought, uint256 minBaseBought, uint256 deadline, address buyer, address recipient, address tokensBoughtExchangeAddr) private returns (uint256) {
        require(block.timestamp <= deadline, "block.timestamp beyond deadline");
        require(tokensSold > 0 && minTokensBought > 0 && minBaseBought > 0, "tokensSold, minTokensBought, minBaseBought should be greater than 0");
        require(tokensBoughtExchangeAddr != address(this) && tokensBoughtExchangeAddr != address(0), "tokensBoughtExchangeAddr cann't be this self or zero address");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 baseBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        require(baseBought >= minBaseBought, "baseBought should be greater than or equal to minBaseBought");
        // todo: usdt have no return !!!
        require(exchangeToken.transferFrom(buyer, address(this), tokensSold), "transfer exchange token fail");
        
        // fixme: if send base fail ?
        // todo: usdt have no return !!!
        // receipt != msg.sender ?? different between baseToTokenTransferInput ?
        uint256 tokensBought = Exchange(tokensBoughtExchangeAddr).baseToTokenTransferInput(minTokensBought, deadline, recipient).value(baseBought);
        // todo log
        // log.EthPurchase(buyer, tokens_sold, wei_bought)
        return tokensBought;
    }
    
    // @notice Convert Tokens (self.token) to Tokens (token_addr).
    // @dev User specifies exact input and minimum output.
    // @param tokens_sold Amount of Tokens sold.
    // @param min_tokens_bought Minimum Tokens (token_addr) purchased.
    // @param min_eth_bought Minimum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param token_addr The address of the token being purchased.
    // @return Amount of Tokens (token_addr) bought.
    function tokenToTokenSwapInput(uint256 tokensSold, uint256 minTokensBought, uint256 minBaseBought, uint256 deadline, address tokensBoughtAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokensBoughtAddr);
        return tokenToTokenInput(tokensSold, minTokensBought, minBaseBought, deadline, msg.sender, msg.sender, exchangeAddr);
    }
    
    // @notice Convert Tokens (self.token) to Tokens (token_addr) and transfers
    //         Tokens (token_addr) to recipient.
    // @dev User specifies exact input and minimum output.
    // @param tokens_sold Amount of Tokens sold.
    // @param min_tokens_bought Minimum Tokens (token_addr) purchased.
    // @param min_eth_bought Minimum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output ETH.
    // @param token_addr The address of the token being purchased.
    // @return Amount of Tokens (token_addr) bought.
    function tokenToTokenTransferInput(uint256 tokensSold, uint256 minTokensBought, uint256 minBaseBought, uint256 deadline, address recipient, address tokensBoughtAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokensBoughtAddr);
        return tokenToTokenInput(tokensSold, minTokensBought, minBaseBought, deadline, msg.sender, recipient, exchangeAddr);
    }
    
    function tokenToTokenOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxBaseSold, uint256 deadline, address buyer, address recipient, address tokensSoldExchangeAddr) private returns (uint256) {
        require(block.timestamp <= deadline, "block.timestamp beyond deadline");
        require(tokensBought > 0 && maxTokensSold > 0 && maxBaseSold > 0, "tokensBought, maxTokensSold, maxBaseSold should be greater than 0");
        require(tokensSoldExchangeAddr != address(this) && tokensSoldExchangeAddr != address(0), "tokensSoldExchangeAddr cann't be this self or zero address");
        uint256 baseBought = Exchange(tokensSoldExchangeAddr).getBaseToTokenOutputPrice(tokensBought);
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(baseBought, tokenReserve, address(this).balance);
        require(tokensSold <= maxTokensSold && baseBought <= maxBaseSold,
            "tokensSold should be greater than or equal to maxTokensSold, and baseBought should be greater than or equal to maxBaseSold");
        // todo: usdt have no return !!!
        require(exchangeToken.transferFrom(buyer, address(this), tokensSold), "transfer exchange token fail");
        uint256 baseSold = Exchange(tokensSoldExchangeAddr).baseToTokenTransferOutput(tokensBought, deadline, recipient).value(baseBought);
        // todo log
        // log.EthPurchase(buyer, tokens_sold, eth_bought)
        return tokensSold;
    }
    
    // @notice Convert Tokens (self.token) to Tokens (token_addr).
    // @dev User specifies maximum input and exact output.
    // @param tokens_bought Amount of Tokens (token_addr) bought.
    // @param max_tokens_sold Maximum Tokens (self.token) sold.
    // @param max_eth_sold Maximum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param token_addr The address of the token being purchased.
    // @return Amount of Tokens (self.token) sold.
    function tokenToTokenSwapOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxBaseSold, uint256 deadline, address tokensSoldAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokensSoldAddr);
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxBaseSold, deadline, msg.sender, msg.sender, exchangeAddr);
    }
    
    // @notice Convert Tokens (self.token) to Tokens (token_addr) and transfers
    //         Tokens (token_addr) to recipient.
    // @dev User specifies maximum input and exact output.
    // @param tokens_bought Amount of Tokens (token_addr) bought.
    // @param max_tokens_sold Maximum Tokens (self.token) sold.
    // @param max_eth_sold Maximum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output ETH.
    // @param token_addr The address of the token being purchased.
    // @return Amount of Tokens (self.token) sold.
    function tokenToTokenTransferOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxBaseSold, uint256 deadline, address recipient, address tokensSoldAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokensSoldAddr);
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxBaseSold, deadline, msg.sender, recipient, exchangeAddr);
    }
    
    // @notice Convert Tokens (self.token) to Tokens (exchange_addr.token).
    // @dev Allows trades through contracts that were not deployed from the same factory.
    // @dev User specifies exact input and minimum output.
    // @param tokens_sold Amount of Tokens sold.
    // @param min_tokens_bought Minimum Tokens (token_addr) purchased.
    // @param min_eth_bought Minimum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param exchange_addr The address of the exchange for the token being purchased.
    // @return Amount of Tokens (exchange_addr.token) bought.
    function tokenToExchangeSwapInput(uint256 tokensSold, uint256 minTokensBought, uint256 minBaseBought, uint256 deadline, address exchangeAddr) public returns (uint256) {
        return tokenToTokenInput(tokensSold, minTokensBought, minBaseBought, deadline, msg.sender, msg.sender, exchangeAddr);
    }
    
    // @notice Convert Tokens (self.token) to Tokens (exchange_addr.token) and transfers
    //         Tokens (exchange_addr.token) to recipient.
    // @dev Allows trades through contracts that were not deployed from the same factory.
    // @dev User specifies exact input and minimum output.
    // @param tokens_sold Amount of Tokens sold.
    // @param min_tokens_bought Minimum Tokens (token_addr) purchased.
    // @param min_eth_bought Minimum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output ETH.
    // @param exchange_addr The address of the exchange for the token being purchased.
    // @return Amount of Tokens (exchange_addr.token) bought.
    function tokenToExchangeTransferInput(uint256 tokensSold, uint256 minTokensBought, uint256 minBaseBought, uint256 deadline, address recipient, address exchangeAddr) public returns (uint256) {
        require(recipient != address(this) && recipient != address(0), "recipient cann't be this self or zero address");
        return tokenToTokenInput(tokensSold, minTokensBought, minBaseBought, deadline, msg.sender, recipient, exchangeAddr);
    }
    
    // @notice Convert Tokens (self.token) to Tokens (exchange_addr.token).
    // @dev Allows trades through contracts that were not deployed from the same factory.
    // @dev User specifies maximum input and exact output.
    // @param tokens_bought Amount of Tokens (token_addr) bought.
    // @param max_tokens_sold Maximum Tokens (self.token) sold.
    // @param max_eth_sold Maximum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param exchange_addr The address of the exchange for the token being purchased.
    // @return Amount of Tokens (self.token) sold.
    function tokenToExchangeSwapOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxBaseSold, uint256 deadline, address exchangeAddr) public returns (uint256) {
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxBaseSold, deadline, msg.sender, msg.sender, exchangeAddr);
    }
    
    // @notice Convert Tokens (self.token) to Tokens (exchange_addr.token) and transfers
    //         Tokens (exchange_addr.token) to recipient.
    // @dev Allows trades through contracts that were not deployed from the same factory.
    // @dev User specifies maximum input and exact output.
    // @param tokens_bought Amount of Tokens (token_addr) bought.
    // @param max_tokens_sold Maximum Tokens (self.token) sold.
    // @param max_eth_sold Maximum ETH purchased as intermediary.
    // @param deadline Time after which this transaction can no longer be executed.
    // @param recipient The address that receives output ETH.
    // @param token_addr The address of the token being purchased.
    // @return Amount of Tokens (self.token) sold.
    function tokenToExchangeTransferOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxBaseSold, uint256 deadline, address recipient, address exchangeAddr) public returns (uint256) {
        require(recipient != address(this) && recipient != address(0), "recipient cann't be this self or zero address");
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxBaseSold, deadline, msg.sender, recipient, exchangeAddr);
    }

    // @dev Pricing function for converting between ETH and Tokens.
    // @param input_amount Amount of ETH or Tokens being sold.
    // @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
    // @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
    // @return Amount of ETH or Tokens bought.
    function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "inputReserve should be greater than 0, or, outputReserve should be greater than 0");
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }
    
    // @dev Pricing function for converting between ETH and Tokens.
    // @param output_amount Amount of ETH or Tokens being bought.
    // @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
    // @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
    // @return Amount of ETH or Tokens sold.
    function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "inputReserve should be greater than 0, or, outputReserve should be greater than 0");
        uint256 numerator = inputReserve * outputAmount * 1000;
        uint256 denominator = (outputReserve - outputAmount) * 997;
        return numerator / denominator + 1;
    }
    
    // @notice Public price function for ETH to Token trades with an exact input.
    // @param eth_sold Amount of ETH sold.
    // @return Amount of Tokens that can be bought with input ETH.
    function getBaseToTokenInputPrice(uint256 baseSold) public view returns (uint256) {
        require(baseSold > 0, "baseSold should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        return getInputPrice(baseSold, address(this).balance, tokenReserve);
    }
    
    // @notice Public price function for ETH to Token trades with an exact output.
    // @param tokens_bought Amount of Tokens bought.
    // @return Amount of ETH needed to buy output Tokens.
    function getBaseToTokenOutputPrice(uint256 tokensBought) public view returns (uint256) {
        require(tokensBought > 0, "tokensBought should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 baseSold = getOutputPrice(tokensBought, address(this).balance, tokenReserve);
        return baseSold;
    }
    
    // @notice Public price function for Token to ETH trades with an exact input.
    // @param tokens_sold Amount of Tokens sold.
    // @return Amount of ETH that can be bought with input Tokens.
    function getTokenToBaseInputPrice(uint256 tokensSold) public view returns(uint256) {
        require(tokensSold > 0, "tokensSold should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        uint256 baseBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        return baseBought;
    }
    
    // @notice Public price function for Token to ETH trades with an exact output.
    // @param eth_bought Amount of output ETH.
    // @return Amount of Tokens needed to buy output ETH.
    function getTokenToBaseOutputPrice(uint256 baseBought) public view returns(uint256) {
        require(baseBought > 0, "baseBought should be greater than 0");
        uint256 tokenReserve = exchangeToken.balanceOf(address(this));
        return getOutputPrice(baseBought, tokenReserve, address(this).balance);
    }
}
