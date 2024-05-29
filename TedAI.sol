// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/utils/structs/EnumerableSet.sol";

contract TedAI is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    EnumerableSet.AddressSet private participants;
    uint256 public constant INITIAL_SUPPLY = 66e9 * 1e18;
    uint256 public saleAllocation = 26.4e9 * 1e18;
    uint256 public developmentAllocation = 13.2e9 * 1e18;
    uint256 public marketingAllocation = 13.2e9 * 1e18;
    uint256 public liquidityPoolAllocation = 6.6e9 * 1e18;
    uint256 public communityRewardsAllocation = 6.6e9 * 1e18;
    uint256 public totalBurned;
    uint256 public rewardPool;
    uint256 public rewardPoolActivationTime;
    uint256 public currentRewardPeriod;
    uint256 public lastRewardClaimTime;
    uint256 public unclaimedRewards;
    uint256 public totalRedistributionAmount;
    uint256 private _initialTotalSupply;
    mapping(address => uint256) public redistributionAmounts;
    mapping(uint256 => uint256) public rewardPeriods;
    mapping(address => bool) private exemptFromTransferCheck;

    address public TedAILPAddress;
    address public TedAIDEVAddress;
    address public TedAIMarketingAddress;
    address public TedAIRewardsAddress;
	address public TedAISaleAddress;
    address public pair;

    event TokensRedistributed(address indexed participant, uint256 amount);
    event AllocationTransferred(string allocationType, address to, uint256 amount);
    event TokenBalanceUpdated(uint256 tedBalance, uint256 totalValue);
    event RewardAdded(uint256 rewardAmount);
    event SpendingApproved(address indexed liquidity, address indexed development, address indexed marketing, address rewards, address sale);
    event TokensBurned(address indexed from, uint256 amount);

    constructor() ERC20("TedAI", "TedAI") ERC20Permit("TedAI") {
        _mint(msg.sender, INITIAL_SUPPLY);
        _initialTotalSupply = INITIAL_SUPPLY ;
        _updateExemptions();
    }
	
	function fundContract() public onlyOwner {
		_transfer(msg.sender, address(this), 66e9 * 1e18);
	}

    function _updateExemptions() internal {
        exemptFromTransferCheck[address(this)] = true;
        exemptFromTransferCheck[TedAIDEVAddress] = true;
        exemptFromTransferCheck[TedAILPAddress] = true;
        exemptFromTransferCheck[TedAIMarketingAddress] = true;
        exemptFromTransferCheck[TedAIRewardsAddress] = true;
        exemptFromTransferCheck[owner()] = true;
        exemptFromTransferCheck[TedAISaleAddress] = true;
    }

    function setAllocationAddresses(
        address _tedAIDEVAddress,
        address _tedAILPAddress,
        address _tedAIMarketingAddress,
        address _tedAIRewardsAddress,
	    address _tedAISaleAddress
    ) external onlyOwner {
        require(_tedAIDEVAddress != address(0), "Invalid TedAIDEV address");
        require(_tedAILPAddress != address(0), "Invalid TedAILP address");
        require(_tedAIMarketingAddress != address(0), "Invalid TedAIMarketing address");
        require(_tedAIRewardsAddress != address(0), "Invalid TedAIRewards address");
        require(_tedAISaleAddress != address(0), "Invalid TedAISale address");

        TedAIDEVAddress = _tedAIDEVAddress;
        TedAILPAddress = _tedAILPAddress;
        TedAIMarketingAddress = _tedAIMarketingAddress;
        TedAIRewardsAddress = _tedAIRewardsAddress;
		TedAISaleAddress = _tedAISaleAddress;
    }

    function transferAllAllocations() external onlyOwner {
        _transferAllocation("Liquidity Pool", TedAILPAddress, liquidityPoolAllocation);
        _transferAllocation("Development", TedAIDEVAddress, developmentAllocation);
        _transferAllocation("Marketing", TedAIMarketingAddress, marketingAllocation);
        _transferAllocation("Community Rewards", TedAIRewardsAddress, communityRewardsAllocation);
		_transferAllocation("Token Sale", TedAISaleAddress, saleAllocation);
    }

    function _transferAllocation(string memory allocationType, address to, uint256 amount) internal {
        if (to != address(0) && amount > 0) {
            _transfer(address(this), to, amount);
            emit AllocationTransferred(allocationType, to, amount);
            if (keccak256(bytes(allocationType)) == keccak256("Liquidity Pool")) liquidityPoolAllocation = 0;
            if (keccak256(bytes(allocationType)) == keccak256("Development")) developmentAllocation = 0;
            if (keccak256(bytes(allocationType)) == keccak256("Marketing")) marketingAllocation = 0;
            if (keccak256(bytes(allocationType)) == keccak256("Community Rewards")) communityRewardsAllocation = 0;
            if (keccak256(bytes(allocationType)) == keccak256("Token Sale")) saleAllocation = 0;
        }
    }

    function approveAllSpending() external onlyOwner {
        _approveAllocation(TedAILPAddress, liquidityPoolAllocation);
        _approveAllocation(TedAIDEVAddress, developmentAllocation);
        _approveAllocation(TedAIMarketingAddress, marketingAllocation);
        _approveAllocation(TedAIRewardsAddress, communityRewardsAllocation);
        _approveAllocation(TedAISaleAddress, saleAllocation);

        emit SpendingApproved(TedAILPAddress, TedAIDEVAddress, TedAIMarketingAddress, TedAIRewardsAddress, TedAISaleAddress);
    }

    function _approveAllocation(address spender, uint256 amount) internal {
        if (amount > 0) {
            _approve(address(this), spender, amount);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Pausable) {}

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(amount > 0, "Transfer amount must be greater than zero");

        bool isExempt = exemptFromTransferCheck[sender] || exemptFromTransferCheck[recipient];
        uint256 burnAmount = 0;
        uint256 rewardAmount = 0;

        if (!isExempt && sender != address(0) && recipient != address(0)) {
            if (sender == pair || recipient == pair) {
                burnAmount = _calculateBurnAmount(amount);
                rewardAmount = _calculateRewardAmount(amount, burnAmount);
            }
        }

        uint256 tax = burnAmount + rewardAmount;
        require(balanceOf(sender) >= amount, "Transfer amount exceeds balance");

        super._transfer(sender, recipient, amount - tax);

        if (burnAmount > 0) {
            _burn(sender, burnAmount);
            totalBurned +=  burnAmount ;
            emit TokensBurned(sender, burnAmount);
        }

        if (rewardAmount > 0) {
            super._transfer(sender, address(this), rewardAmount);
            rewardPool += rewardAmount;
            if(rewardPoolActivationTime == 0){
               rewardPoolActivationTime = block.timestamp;
            }
            emit RewardAdded(rewardAmount);
        }
    }

    function _calculateBurnAmount(uint256 amount) private view returns (uint256) {
        if (totalBurned >= _initialTotalSupply / 2) return 0;
        uint256 burnAmount = (amount * 3) / 1000;
        uint256 potentialTotalBurned = totalBurned + burnAmount;
        if (potentialTotalBurned > _initialTotalSupply / 2) {
            burnAmount = _initialTotalSupply / 2 - totalBurned;
        }
        return burnAmount;
    }

    function _calculateRewardAmount(uint256 amount, uint256 burnAmount) private pure returns (uint256) {
        uint256 rewardPercentage = burnAmount == 0 ? 10 : 7;
        return (amount * rewardPercentage) / 1000;
    }

    function calculateReward(address user) public view returns (uint256) {
        uint256 userBalance = balanceOf(user);
        uint256 circulatingSupply = totalSupply() - _nonCirculatingSupply();
        require(circulatingSupply > 0, "Circulating supply cannot be zero");

        uint256 userShare = (userBalance * 1e18) / circulatingSupply;
        uint256 rewardBase = 1e18;
        uint256 reward = (userShare * rewardBase) / 1e18;

        return reward;
    }

    function claimRewards() external nonReentrant {
        require(block.timestamp >= rewardPoolActivationTime + 30 days, "Rewards not yet available");

        uint256 periodElapsed = (block.timestamp - rewardPoolActivationTime) / 30 days;
        require(periodElapsed == currentRewardPeriod, "Either not yet time to claim or the claim period has passed");

        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards available");
        require(rewardPool >= reward, "Insufficient reward pool");

        rewardPool -= reward;
        _transfer(address(this), msg.sender, reward);
        emit TokensRedistributed(msg.sender, reward);
    }

    function allocateUnclaimedRewards() external {
        uint256 periodElapsed = (block.timestamp - rewardPoolActivationTime) / 30 days;
        require(periodElapsed > currentRewardPeriod, "Current reward period has not yet ended");

        if (rewardPeriods[currentRewardPeriod] > 0) {
            marketingAllocation += rewardPeriods[currentRewardPeriod];
            emit AllocationTransferred("Unclaimed Rewards to Marketing", address(this), rewardPeriods[currentRewardPeriod]);
            rewardPeriods[currentRewardPeriod] = 0;
        }

        currentRewardPeriod = periodElapsed + 1;
    }

    function calculateCirculatingSupply() public view returns (uint256) {
        return totalSupply() - _nonCirculatingSupply();
    }

    function _nonCirculatingSupply() internal view returns (uint256) {
        return balanceOf(TedAIDEVAddress) +
            balanceOf(TedAILPAddress) +
            balanceOf(TedAIMarketingAddress) +
            balanceOf(TedAIRewardsAddress) +
            balanceOf(address(this));
    }

    function setPairAddress(address _pair) external onlyOwner {
        pair = _pair;
    }
}