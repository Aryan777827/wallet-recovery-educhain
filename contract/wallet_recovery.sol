// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SmartWalletRecovery {
    address public owner;
    uint256 public recoveryApprovalsNeeded;

    mapping(address => bool) public guardians;
    mapping(address => mapping(address => bool)) public recoveryVotes;
    mapping(address => uint256) public voteCounts;
    address[] public guardianList;

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event GuardianAdded(address guardian);
    event GuardianRemoved(address guardian);
    event RecoveryVoteSubmitted(address guardian, address newOwnerCandidate);
    event RecoveryVoteCleared(address candidate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyGuardian() {
        require(guardians[msg.sender], "Not a guardian");
        _;
    }

    constructor(address[] memory _guardians, uint256 _approvalsNeeded) {
        require(_guardians.length >= _approvalsNeeded, "Not enough guardians");
        owner = msg.sender;
        recoveryApprovalsNeeded = _approvalsNeeded;

        for (uint256 i = 0; i < _guardians.length; i++) {
            guardians[_guardians[i]] = true;
            guardianList.push(_guardians[i]);
            emit GuardianAdded(_guardians[i]);
        }
    }

    receive() external payable {}

    function transferETH(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
    }

    function addGuardian(address _guardian) external onlyOwner {
        require(!guardians[_guardian], "Already a guardian");
        guardians[_guardian] = true;
        guardianList.push(_guardian);
        emit GuardianAdded(_guardian);
    }

    function removeGuardian(address _guardian) external onlyOwner {
        require(guardians[_guardian], "Not a guardian");
        guardians[_guardian] = false;

        // Remove from list
        for (uint256 i = 0; i < guardianList.length; i++) {
            if (guardianList[i] == _guardian) {
                guardianList[i] = guardianList[guardianList.length - 1];
                guardianList.pop();
                break;
            }
        }

        emit GuardianRemoved(_guardian);
    }

    function voteToRecover(address _newOwner) external onlyGuardian {
        require(!recoveryVotes[_newOwner][msg.sender], "Already voted");

        recoveryVotes[_newOwner][msg.sender] = true;
        voteCounts[_newOwner] += 1;

        emit RecoveryVoteSubmitted(msg.sender, _newOwner);

        if (voteCounts[_newOwner] >= recoveryApprovalsNeeded) {
            address oldOwner = owner;
            owner = _newOwner;
            _resetVotes(_newOwner);
            emit OwnershipTransferred(oldOwner, _newOwner);
        }
    }

    function _resetVotes(address _candidate) internal {
        for (uint256 i = 0; i < guardianList.length; i++) {
            recoveryVotes[_candidate][guardianList[i]] = false;
        }
        voteCounts[_candidate] = 0;
        emit RecoveryVoteCleared(_candidate);
    }

    function getGuardians() public view returns (address[] memory) {
        return guardianList;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

