pragma solidity ^0.4.19;


import "./SafeMath.sol";
import "./Ownable.sol";
import "./LMDA.sol";


contract ICO is Ownable {
    
    using SafeMath for uint256;
    
    event AidropInvoked();
    event MainSaleActivated();
    event TokenPurchased(address recipient, uint256 tokens);
    event DeadlineExtended(uint256 daysExtended);
    event DeadlineShortened(uint256 daysShortenedBy);
    event OffChainPurchaseMade(address recipient, uint256 tokensBought);
    event TokenPriceChanged(string stage, uint256 newTokenPrice);
    event ExchangeRateChanged(string stage, uint256 newRate);
    event BonusChanged(string stage, uint256 newBonus);
    event TokensWithdrawn(address to, uint256 LMDA); 
    event TokensUnpaused();
    event ICOPaused(uint256 timeStamp);
    event ICOUnpaused(uint256 timeStamp);  
    
    address public receiverOne;
    address public receiverTwo;
    address public receiverThree;
    address public reserveAddress;
    address public teamAddress;
    
    uint256 public endTime;
    uint256 public tokenPriceForPreICO;
    uint256 public rateForPreICO;
    uint256 public tokenPriceForMainICO;
    uint256 public rateForMainICO;
    uint256 public tokenCapForPreICO;
    uint256 public tokenCapForMainICO;
    uint256 public bonusForPreICO;
    uint256 public bonusForMainICO;
    uint256 public tokensSold;
    uint256 public timePaused;
    bool public icoPaused;
    
    
    enum StateOfICO {
        PRE,
        MAIN
    }
    
    StateOfICO public stateOfICO;
    
    LMDA public lmda;

    mapping (address => uint256) public investmentOf;
    
    
    /**
     * Functions with this modifier can only be called when the ICO 
     * is not paused.
     * */
    modifier whenNotPaused {
        require(!icoPaused);
        _;
    }
    
    
    /**
     * Constructor functions creates a new instance of the LMDA token 
     * and automatically distributes tokens to the reserve and team 
     * addresses. The constructor also initializes all of the state 
     * variables of the ICO contract. 
     * */
    function ICO() public {
        lmda = new LMDA();
        owner = 0x2488F34A2c2eBabbb44d5E8AD81E1D689fD76E50;
        receiverOne = 0x43adebFC525FEcf9b2E91a4931E4a003a1F0d959;   //Pre ICO
        receiverTwo = 0xB447292181296B8c7F421F1182be20640dc8Bb05;   //Pre ICO
        receiverThree = 0x3f68b06E7C0E87828647Dbba0b5beAef3822b7Db; //Main ICO
        reserveAddress = 0x7d05F660124B641b74b146E9aDA60D7D836dcCf5;
        teamAddress = 0xAD942E5085Af6a7A4C31f17ac687F8d5d7C0225C;
        lmda.transfer(reserveAddress, 90000000e18);
        lmda.transfer(teamAddress, 35500000e18);
        stateOfICO = StateOfICO.PRE;
        endTime = now.add(21 days);
        tokenPriceForPreICO = 0.00005 ether;
        rateForPreICO = 20000;
        tokenPriceForMainICO = 0.00007 ether;
        rateForMainICO = 14285; // should be 14,285.7143 
        tokenCapForPreICO = 144000000e18;
        tokenCapForMainICO = 374500000e18; 
        bonusForPreICO = 20;
        bonusForMainICO = 15;
        tokensSold = 0;
        icoPaused= false;
    }
    
    
    /**
     * This function allows the owner of the contract to airdrop LMDA tokens 
     * to a list of addresses, so long as a list of values is also provided.
     * 
     * @param _addrs The list of recipient addresses
     * @param _values The number of tokens each address will receive 
     * */
    function airdrop(address[] _addrs, uint256[] _values) public onlyOwner {
        require(lmda.balanceOf(address(this)) >= getSumOfValues(_values));
        require(_addrs.length <= 100 && _addrs.length == _values.length);
        for(uint i = 0; i < _addrs.length; i++) {
            lmda.transfer(_addrs[i], _values[i]);
        }
        AidropInvoked();
    }
    
    
    /**
     * Function is called internally by the airdrop() function to ensure that 
     * there are enough tokens remaining to execute the airdrop. 
     * 
     * @param _values The list of values representing the tokens to be sent
     * @return Returns the sum of all the values
     * */
    function getSumOfValues(uint256[] _values) internal pure returns(uint256 sum) {
        sum = 0;
        for(uint i = 0; i < _values.length; i++) {
            sum = sum.add(_values[i]);
        }
    }
    
    
    /**
     * Function allows the owner to activate the main sale.
     * */
    function activateMainSale() public onlyOwner whenNotPaused {
        require(now >= endTime || tokensSold >= tokenCapForPreICO);
        stateOfICO = StateOfICO.MAIN;
        endTime = now.add(49 days);
        MainSaleActivated();
    }


    /**
     * Fallback function invokes the buyToknes() method when ETH is recieved 
     * to enable the automatic distribution of tokens to investors.
     * */
    function() public payable {
        buyTokens(msg.sender);
    }
    
    
    /**
     * Allows investors to buy tokens for themselves or others by explicitly 
     * invoking the function using the ABI / JSON Interface of the contract.
     * 
     * @param _addr The address of the recipient
     * */
    function buyTokens(address _addr) public payable whenNotPaused {
        require(now <= endTime && _addr != 0x0);
        require(lmda.balanceOf(address(this)) > 0);
        if(stateOfICO == StateOfICO.PRE && tokensSold >= tokenCapForPreICO) {
            revert();
        } else if(stateOfICO == StateOfICO.MAIN && tokensSold >= tokenCapForMainICO) {
            revert();
        }
        uint256 toTransfer = msg.value.mul(getRate().mul(getBonus())).div(100).add(getRate());
        lmda.transfer(_addr, toTransfer);
        tokensSold = tokensSold.add(toTransfer);
        investmentOf[msg.sender] = investmentOf[msg.sender].add(msg.value);
        TokenPurchased(_addr, toTransfer);
        forwardFunds();
    }
    
    
    /**
     * Allows the owner to send tokens to investors who paid with other currencies.
     * 
     * @param _recipient The address of the receiver 
     * @param _value The total amount of tokens to be sent
     * */
    function processOffChainPurchase(address _recipient, uint256 _value) public onlyOwner {
        require(lmda.balanceOf(address(this)) >= _value);
        require(_value > 0 && _recipient != 0x0);
        lmda.transfer(_recipient, _value);
        tokensSold = tokensSold.add(_value);
        OffChainPurchaseMade(_recipient, _value);
    }
    
    
    /**
     * Function is called internally by the buyTokens() function in order to send 
     * ETH to owners of the ICO automatically. 
     * */
    function forwardFunds() internal {
        if(stateOfICO == StateOfICO.PRE) {
            receiverOne.transfer(msg.value.div(2));
            receiverTwo.transfer(msg.value.div(2));
        } else {
            receiverThree.transfer(msg.value);
        }
    }
    
    
    /**
     * Allows the owner to extend the deadline of the current ICO phase.
     * 
     * @param _daysToExtend The number of days to extend the deadline by.
     * */
    function extendDeadline(uint256 _daysToExtend) public onlyOwner {
        endTime = endTime.add(_daysToExtend.mul(1 days));
        DeadlineExtended(_daysToExtend);
    }
    
    
    /**
     * Allows the owner to shorten the deadline of the current ICO phase.
     * 
     * @param _daysToShortenBy The number of days to shorten the deadline by.
     * */
    function shortenDeadline(uint256 _daysToShortenBy) public onlyOwner {
        if(now.sub(_daysToShortenBy.mul(1 days)) < endTime) {
            endTime = now;
        }
        endTime = endTime.sub(_daysToShortenBy.mul(1 days));
        DeadlineShortened(_daysToShortenBy);
    }
    
    
    /**
     * Allows the owner to change the token price of the current phase. 
     * This function will automatically calculate the new exchange rate. 
     * 
     * @param _newTokenPrice The new price of the token.
     * */
    function changeTokenPrice(uint256 _newTokenPrice) public onlyOwner {
        require(_newTokenPrice > 0);
        if(stateOfICO == StateOfICO.PRE) {
            if(tokenPriceForPreICO == _newTokenPrice) { revert(); } 
            tokenPriceForPreICO = _newTokenPrice;
            rateForPreICO = uint256(1e18).div(tokenPriceForPreICO);
            TokenPriceChanged("Pre ICO", _newTokenPrice);
        } else {
            if(tokenPriceForMainICO == _newTokenPrice) { revert(); } 
            tokenPriceForMainICO = _newTokenPrice;
            rateForMainICO = uint256(1e18).div(tokenPriceForMainICO);
            TokenPriceChanged("Main ICO", _newTokenPrice);
        }
    }
    
    
    /**
     * Allows the owner to change the exchange rate of the current phase.
     * This function will automatically calculate the new token price. 
     * 
     * @param _newRate The new exchange rate.
     * */
    function changeRateOfToken(uint256 _newRate) public onlyOwner {
        require(_newRate > 0);
        if(stateOfICO == StateOfICO.PRE) {
            if(rateForPreICO == _newRate) { revert(); }
            rateForPreICO = _newRate;
            tokenPriceForPreICO = uint256(1e18).div(rateForPreICO);
            ExchangeRateChanged("Pre ICO", _newRate);
        } else {
            if(rateForMainICO == _newRate) { revert(); }
            rateForMainICO = _newRate;
            rateForMainICO = uint256(1e18).div(rateForMainICO);
            ExchangeRateChanged("Main ICO", _newRate);
        }
    }
    
    
    /**
     * Allows the owner to change the bonus of the current phase.
     * 
     * @param _newBonus The new bonus percentage.
     * */
    function changeBonus(uint256 _newBonus) public onlyOwner {
        if(stateOfICO == StateOfICO.PRE) {
            if(bonusForPreICO == _newBonus) { revert(); }
            bonusForPreICO = _newBonus;
            BonusChanged("Pre ICO", _newBonus);
        } else {
            if(bonusForMainICO == _newBonus) { revert(); }
            bonusForMainICO = _newBonus;
            BonusChanged("Main ICO", _newBonus);
        }
    }
    
    
    /**
     * Allows the owner to withdraw all unsold tokens to his wallet. 
     * */
    function withdrawUnsoldTokens() public onlyOwner {
        TokensWithdrawn(owner, lmda.balanceOf(address(this)));
        lmda.transfer(owner, lmda.balanceOf(address(this)));
    }
    
    
    /**
     * Allows the owner to unpause the LMDA token.
     * */
    function unpauseToken() public onlyOwner {
        TokensUnpaused();
        lmda.unpause();
    }
    
    
    /**
     * Allows the owner to claim back ownership of the LMDA token contract.
     * */
    function transferTokenOwnership() public onlyOwner {
        lmda.transferOwnership(owner);
    }
    
    
    /**
     * Allows the owner to pause the ICO.
     * */
    function pauseICO() public onlyOwner whenNotPaused {
        require(now < endTime);
        timePaused = now;
        icoPaused = true;
        ICOPaused(now);
    }
    
  
    /**
     * Allows the owner to unpause the ICO.
     * */
    function unpauseICO() public onlyOwner {
        endTime = endTime.add(now.sub(timePaused));
        timePaused = 0;
        icoPaused = false;
        ICOUnpaused(now);
    }
    
    
    /**
     * @return The total amount of tokens that have been sold.
     * */
    function getTokensSold() public view returns(uint256 _tokensSold) {
        _tokensSold = tokensSold;
    }
    
    
    /**
     * @return The current bonuse percentage.
     * */
    function getBonus() public view returns(uint256 _bonus) {
        if(stateOfICO == StateOfICO.PRE) { 
            _bonus = bonusForPreICO;
        } else {
            _bonus = bonusForMainICO;
        }
    }
    
    
    /**
     * @return The current exchange rate.
     * */
    function getRate() public view returns(uint256 _exchangeRate) {
        if(stateOfICO == StateOfICO.PRE) {
            _exchangeRate = rateForPreICO;
        } else {
            _exchangeRate = rateForMainICO;
        }
    }
    
    
    /**
     * @return The current token price. 
     * */
    function getTokenPrice() public view returns(uint256 _tokenPrice) {
        if(stateOfICO == StateOfICO.PRE) {
            _tokenPrice = tokenPriceForPreICO;
        } else {
            _tokenPrice = tokenPriceForMainICO;
        }
    }
}