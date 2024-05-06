// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/manager/AccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import './FundECtools.sol';

contract ECFund is ERC20, AccessManager, ReentrancyGuard, FundECtools {

    using SafeERC20 for IERC20;
    
    uint256 public ETFprice;
    uint256 public fundOperationsCommision; // xx,xx% format, sets like uint256 xxxx
    address public fundTreasury;

    IERC20 public _USDT_ADDRESS;
    IERC20 public _DAI_ADDRESS;

    address secAdm = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db; // <= CHANGE TO YURI/ARTEM
    address thirdAdm = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // <= CHANGE TO YURI/ARTEM
    
    uint64 public constant BOT = 8;
    uint64 public constant SECOND_ADM = 9;
    uint64 public constant THIRD_ADM = 10;
    uint64 public constant INVESTOR = 11;

    struct Lock {
        uint256 releaseTime;
        uint256 lockedAmount;
    }
    
    mapping(address => uint256[]) internal transactionsSell; 
    mapping(address => Lock[]) public locks;
    mapping(address => uint256) public totalLocked;
    mapping (address => uint256) public avaivableForWithdraw; // decimals 18

    // EVENTS
    event newPrice(address setterPrice, uint256 newPrice);
    event newCommision(address setterComm, uint256 newCommision);
    event newTreasury(address setterTreasury, address newTreasury);
    event boughtWithUSDT(address buyerUSDT, uint256 boughtTokensAmountUSDT, uint256 USDTReceived, uint256 timePurchaseUSDT);
    event tokenSoldUSDT(address sellerUSDT, uint256 tokensSold, uint256 USDTreceived, uint256 currentETFprice, uint256 timeSoldUSDT);
    event sellTransactionQueu(address seller, uint256 amountUSD, uint256 amountETF, uint256 timeSell);
    event boughtWithDAI(address buyerDAI, uint256 boughtTokensAmountDAI, uint256 DAIReceived, uint256 timePurchaseDAI);

    modifier onlyRoles(uint64[] memory _roleIDs) {
        bool hasRole = false;
        for (uint i = 0; i < _roleIDs.length; i++) {
            if (_hasRole(_roleIDs[i], msg.sender)) {
                hasRole = true;
                break;
            }
        }
        require(hasRole, "AccessManager: caller does not have the required role");
        _;
    }

    modifier beforeSell(uint256 _amount) {
        address seller = msg.sender;
        require(
          balanceOf(seller) >= _amount,
          "not enough tokens"
        );

        require(
            avaivableForWithdraw[seller] >= _amount,
            "not enougth to withdraw"
        );

        if (!_hasRole(INVESTOR, seller)) {
            _grantRole(INVESTOR, seller, 0, 1 days);
            revert("try again: your wallet is now registered");
        }

        uint256 amount = _amount * (10 ** 18);

        uint256 amountUSDT = _amount * ETFprice * (10**6);
        uint256 afterCommAmount = amountUSDT - (amountUSDT * fundOperationsCommision / 10000);

        transactionsSell[seller].push(afterCommAmount);

        avaivableForWithdraw[msg.sender] -= amount;

        emit sellTransactionQueu(msg.sender, afterCommAmount, amount, block.timestamp);
        _;
    }

    uint64[] internal adminRoles3 = new uint64[](3);
    uint64[] internal adminRoles4 = new uint64[](4);

    constructor(address initialAdmin) ERC20("EMETF", "emETF") AccessManager(initialAdmin){
        initialAdmin = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4; 

        _grantRole(SECOND_ADM, secAdm, 0, 0);
        _grantRole(THIRD_ADM, thirdAdm, 0, 0);
        _grantRole(ADMIN_ROLE, initialAdmin, 0, 0);

        fundTreasury = msg.sender;
        ETFprice = 10;

        _USDT_ADDRESS = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        _DAI_ADDRESS = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        
        adminRoles3[0] = ADMIN_ROLE;
        adminRoles3[1] = SECOND_ADM;
        adminRoles3[2] = THIRD_ADM;
    
        adminRoles4[0] = ADMIN_ROLE;
        adminRoles4[1] = SECOND_ADM;
        adminRoles4[2] = THIRD_ADM;
        adminRoles4[3] = BOT;
    }

    // INTERNALS

    function lockToken(address locker, uint256 _lockedAmount, uint256 locktime) public {
        require(_lockedAmount > 0, "not enougth lock amount");
        require(balanceOf(locker) > _lockedAmount, "not enougth balance");
        IERC20(address(this)).safeTransferFrom(locker, address(this), _lockedAmount);
        locks[locker].push(Lock({
            lockedAmount: _lockedAmount,
            releaseTime: block.timestamp + locktime
        }));
        totalLocked[locker] += _lockedAmount;
    }

    function withdrawLockedtoken() public {
        Lock[] storage userLocks = locks[msg.sender];
        uint256 totalWithdrawable = 0;
        for (uint256 i = 0; i < userLocks.length; i++) {
            if (block.timestamp >= userLocks[i].releaseTime) {
                totalWithdrawable += userLocks[i].lockedAmount;
                delete userLocks[i];
            } else {
                break; 
            }
        }
        require(totalWithdrawable > 0, "No tokens available for withdrawal");
        IERC20(address(this)).safeTransfer(msg.sender, totalWithdrawable);
    }

    // HELPERS
    function _hasRole(uint64 _roleID, address client) public view returns(bool) {
        (bool isMember, ) = hasRole(_roleID, client);
        return isMember;
    }

    function getTokenSupply() public view returns(uint256) {
        return totalSupply();
    }

    // PARAMS SETTINGS
    function setPrice(uint256 _ETFprice) public onlyRoles(adminRoles4) {  
        require(_ETFprice != 0);
        ETFprice = _ETFprice;
        emit newPrice(msg.sender, _ETFprice);
    }

    function setComission(uint256 _fundOperationsCommision) public onlyRoles(adminRoles3) {
        require(_fundOperationsCommision != 0);
        fundOperationsCommision = _fundOperationsCommision;
        emit newCommision(msg.sender, _fundOperationsCommision);
    }

    function setTreasuryAddress(address _fundTreasury) public onlyRoles(adminRoles3) {
        require(_fundTreasury != address(0));
        fundTreasury = _fundTreasury;
        emit newTreasury(msg.sender, _fundTreasury);
    }

    // CORE FUNCTIONS 
    // BUY
    function buyWithUSDT(uint256 _amount, uint256 _lockperiod) public payable nonReentrant {
        IERC20 token = _USDT_ADDRESS;
        address _buyer = msg.sender;
        uint256 amount = _amount * (10**6);

        require(
            _amount >= 10, 
            "low ticket"
        );
      
        require(
          IERC20(token).balanceOf(_buyer) >= amount,
          "not enough USDT"
        );

        IERC20(token).safeIncreaseAllowance(address(this), amount);

        require(
            IERC20(token).allowance(_buyer, address(this)) >= amount, 
            "not enough allowance"
        );

        IERC20(token).safeTransferFrom(_buyer, fundTreasury, amount);
        IERC20(token).safeDecreaseAllowance(address(this), amount);

        int256 exchangeRate = getChainlinkDataFeedUSDTLatestAnswer();
        require(exchangeRate >=  0, "Exchange rate cannot be negative");
        uint256 positiveExchangeRate = uint256(exchangeRate);
        uint256 boughtAmount = (amount * 10**12) * (positiveExchangeRate * 10**10) / (ETFprice * decimals());

        _mint(_buyer, boughtAmount);
        avaivableForWithdraw[_buyer] += amount;
        _grantRole(INVESTOR, _buyer, 0, 1 days);

        lockToken(_buyer, amount, _lockperiod);

        emit boughtWithUSDT(_buyer, boughtAmount, amount, block.timestamp);
    }

    function buyWithDAI(uint256 _amount, uint256 _lockperiod) public payable nonReentrant {
        IERC20 token = _DAI_ADDRESS;
        address _buyer = msg.sender;
        uint256 amount = _amount * (10**6); 

        require(
            _amount >= 10, 
            "low ticket"
        );
      
        require(
          IERC20(token).balanceOf(_buyer) >= amount,
          "not enough USDT"
        );

        IERC20(token).safeIncreaseAllowance(address(this), amount);

        require(
            IERC20(token).allowance(_buyer, address(this)) >= amount, 
            "not enough allowance"
        );

        IERC20(token).safeTransferFrom(_buyer, fundTreasury, amount);
        IERC20(token).safeDecreaseAllowance(address(this), amount);

        int256 exchangeRate = getChainlinkDataFeedUSDTLatestAnswer();
        require(exchangeRate >=  0, "Exchange rate cannot be negative");
        uint256 positiveExchangeRate = uint256(exchangeRate);
        uint256 boughtAmount = (amount * 10**12) * (positiveExchangeRate * 10**10) / (ETFprice * decimals());

        _mint(_buyer, boughtAmount);
        avaivableForWithdraw[_buyer] += amount;
        _grantRole(INVESTOR, _buyer, 0, 1 days);

        lockToken(_buyer, amount, _lockperiod);

        emit boughtWithDAI(_buyer, boughtAmount, amount, block.timestamp);
    }

    // SELL
    function sellToken(uint256 _amount) public payable beforeSell(_amount) nonReentrant onlyAuthorized {
        address seller = msg.sender;
        require(
          balanceOf(seller) >= _amount,
          "not enough tokens"
        );

        uint256 afterCommAmount = transactionsSell[seller][0];
        IERC20 token = _USDT_ADDRESS;
        require(
          IERC20(token).balanceOf(address(this)) >= afterCommAmount,
          "not enough USDT"
        );

        transactionsSell[seller].pop();

        uint256 amount = _amount * (10 ** 18);

        _burn(seller, amount);
        avaivableForWithdraw[seller] -= amount;
        IERC20(token).safeTransferFrom(address(this), seller, afterCommAmount);

        emit tokenSoldUSDT(seller, _amount, afterCommAmount, ETFprice, block.timestamp); 
    }

}