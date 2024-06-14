// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BlockPoll} from "../src/BlockPoll.sol";

contract BlockPollPenTest is Test {
    BlockPoll public blockPoll;

    address public owner = address(0x123);
    address public participant1 = address(0x456);
    address public participant2 = address(0x789);
    address public attacker = address(0xBAD);

    function setUp() public {
        blockPoll = new BlockPoll();
        vm.deal(owner, 10 ether);
        vm.deal(participant1, 10 ether);
        vm.deal(participant2, 10 ether);
        vm.deal(attacker, 10 ether);
    }
    // Purpose: Tests for vulnerabilities to reentrancy attacks during the reward withdrawal process.
    // Specification: The contract should prevent reentrant calls that could lead to unintended withdrawals or duplicate transactions.
    // Expected Result: When an attacker attempts to exploit the withdrawReward function via reentrancy, the contract should revert the transaction, ensuring no funds are stolen or double-spent.
    // Security Issue: Reentrancy Attack
    // Security Issue: Reentrancy Attack
    // Potential Damage: Unauthorized withdrawals, financial loss, contract inoperability.
    function testReentrancyOnWithdraw() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Survey 1", options, 100, 10, true);
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        blockPoll.vote(0, 1);
        vm.stopPrank();

        vm.startPrank(owner);
        blockPoll.closeSurvey(0);
        vm.stopPrank();

        vm.startPrank(attacker);
        AttackContract attackContract = new AttackContract(blockPoll, 0);
        vm.expectRevert();
        attackContract.attack{value: 0.1 ether}();
        vm.stopPrank();
    }
    // Purpose: Ensures that surveys can only be closed by authorized users, typically the owner or under specific conditions predefined in the contract.
    // Specification: Unauthorized users, such as attackers, should not be able to close surveys prematurely.
    // Expected Result: Any attempt by an attacker to close a survey should fail, maintaining the integrity and lifecycle of survey operations.
    // Security Issue: Unauthorized Access
    // Potential Damage: Premature survey closure, disrupting survey operations, loss of data integrity.
    function testUnauthorizedCloseSurvey() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Survey 1", options, 100, 10, true);
        vm.stopPrank();

        vm.startPrank(attacker);
        vm.expectRevert("Cannot close survey yet");
        blockPoll.closeSurvey(0);
        vm.stopPrank();
    }
    // Purpose: Verifies that only participants who are due rewards can withdraw them, preventing unauthorized access to funds.
    // Specification: Withdrawals should be restricted to participants with valid claims only.
    // Expected Result: Attempts by non-participants (like an attacker) to withdraw rewards should be rejected, securing the reward distribution system.
    // Security Issue: Unauthorized Access
    // Potential Damage: Unauthorized withdrawal of rewards, financial loss for legitimate participants.
    // Test for reward withdrawal by non-participant
    function testRewardWithdrawalByNonParticipant() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Survey 1", options, 100, 10, true);
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        blockPoll.vote(0, 1);
        vm.stopPrank();

        vm.startPrank(owner);
        blockPoll.closeSurvey(0);
        vm.stopPrank();

        vm.startPrank(attacker);
        vm.expectRevert("No reward available or already claimed.");
        blockPoll.withdrawReward(0);
        vm.stopPrank();
    }
    // Purpose: Tests for reentrancy vulnerabilities in the unstaking function, a common target for attackers trying to manipulate contract state or extract funds illegitimately.
    // Specification: The contract should handle state changes and ether transfers in a manner that prevents reentrancy.
    // Expected Result: The system should revert any reentrant unstaking attempts, ensuring that the stake management remains secure and consistent.
    // Security Issue: Reentrancy Attack
    // Potential Damage: Unauthorized withdrawals, financial loss, contract inoperability.
    function testReentrancyOnUnstake() public {
        vm.startPrank(owner);
        blockPoll.stakeEther{value: 1 ether}();
        ReentrancyAttackContract attackContract = new ReentrancyAttackContract(blockPoll);
        vm.expectRevert();
        attackContract.attack{value: 0.1 ether}();
        vm.stopPrank();
    }
    // Purpose: Checks the robustness of the voting mechanism against rapid, sequential voting attempts that might be used to manipulate survey results.
    // Specification: The contract should enforce one vote per survey per user, preventing any form of vote duplication.
    // Expected Result: Rapid, repeated voting attempts by a single participant should fail after the first valid vote, preserving the fairness and accuracy of the survey.
    // Security Issue: Double Voting
    // Potential Damage: Manipulation of survey results, loss of survey integrity, unfair advantage to certain participants.
    function testVoteManipulation() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Vote Manipulation Survey", options, 100, 10, true);
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();

        // Attempt to vote multiple times in quick succession
        vm.roll(block.number + 1); // Simulate advancing block
        blockPoll.vote(0, 0);
        vm.expectRevert("You can only vote once per survey.");
        blockPoll.vote(0, 1);
        vm.stopPrank();
    }
    // Purpose: Assesses the contract's resilience against denial-of-service attacks that could be executed through rapid staking and unstaking actions.
    // Specification: The contract should efficiently manage frequent state changes without significant performance degradation or susceptibility to DoS.
    // Expected Result: The system should handle repeated staking and unstaking without crashing or slowing down significantly, ensuring availability even under stress.
    // Security Issue: Denial of Service (DoS) Attack
    // Potential Damage: Resource exhaustion, contract slowdown or crash, denial of service to legitimate users.
    function testDoSViaStaking() public {
        vm.startPrank(attacker);
        // Repeatedly stake and unstake to test system's resilience against resource exhaustion
        for (uint i = 0; i < 50; i++) {
            blockPoll.stakeEther{value: 0.01 ether}();
            blockPoll.unstakeEther(0.01 ether);
        }
        vm.stopPrank();
    }
    // Purpose: Evaluates the system's performance and limitations when subjected to high volumes of survey creations, a potential vector for service disruption.
    // Specification: The contract should support a large number of survey creations without failure or excessive gas costs.
    // Expected Result: Successfully creating a high volume of surveys should not degrade the system's performance, confirming scalability.
    // Security Issue: Denial of Service (DoS) Attack via Excessive Survey Creation
    // Potential Damage: Resource exhaustion, contract slowdown or crash, denial of service to legitimate users.    
    function testExcessiveSurveyCreation() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](3);
        options[0] = 1; options[1] = 2; options[2] = 3;
        string memory description = "Standard Survey";

        for (uint i = 0; i < 100; i++) {
            blockPoll.createSurvey(description, options, 50, 100, false);
        }

        vm.stopPrank();
        uint surveyCount = blockPoll.nextSurveyId();
        assertEq(surveyCount, 100, "Survey count does not match expected value.");
    }
    // Purpose: Tests the reward calculation mechanism for potential integer overflow errors, which could be exploited to cause incorrect reward distributions.
    // Specification: Calculations related to rewards should be safe from overflows, ensuring that reward payouts are accurate and within expected limits.
    // Expected Result: The contract should either handle large numbers or revert safely without any overflow, preventing erroneous reward payments.
    // Security Issue: Integer Overflow in Reward Calculation
    // Potential Damage: Incorrect reward distribution, financial loss, contract lock-up.
    function testRewardCalculationOverflow() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1; options[1] = 2;
        blockPoll.createSurvey("Overflow Test", options, 50, 100, true);
        uint surveyId = blockPoll.nextSurveyId() - 1;

        // Simulating a high number of participants with stakes
        for (uint i = 1; i <= 100; i++) {
            address participant = address(uint160(i));
            vm.deal(participant, 10 ether);
            vm.startPrank(participant);
            blockPoll.register(string(abi.encodePacked("User", i)));
            blockPoll.stakeEther{value: 10 ether}();
            blockPoll.vote(surveyId, 0);
            vm.stopPrank();
        }

        // Close survey and trigger reward distribution
        blockPoll.closeSurvey(surveyId);

        // Check if the calculation did not cause overflow and the contract is not locked
        vm.startPrank(participant1);
        vm.expectRevert();
        blockPoll.withdrawReward(surveyId);
        vm.stopPrank();
    }
    // Purpose: Confirms that survey results are protected against unauthorized access, adhering to privacy settings.
    // Specification: Results viewing should be controlled based on permissions, with private surveys restricting access to unauthorized users.
    // Expected Result: Unauthorized attempts to view survey results (by attackers or other non-privileged users) should be blocked, upholding data confidentiality.
    // Security Issue: Unauthorized Access to Private Data
    // Potential Damage: Privacy violation, exposure of sensitive data, loss of user trust.
    function testUnauthorizedAccessToResults() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1; options[1] = 2;
        blockPoll.createSurvey("Access Control Test", options, 50, 100, false); // Results should not be public
        uint surveyId = blockPoll.nextSurveyId() - 1;
        vm.stopPrank();

        vm.startPrank(attacker);
        vm.expectRevert("Not authorized to view results");
        blockPoll.viewResults(surveyId);
        vm.stopPrank();
    }
    // Purpose: This test evaluates the contract's handling of simultaneous actions that might affect the state integrity, specifically targeting scenarios where actions like closing a survey and voting occur around the same time.
    // Specification: The contract should ensure transactional integrity, preventing actions that could lead to inconsistent states, such as voting on a survey that is simultaneously being closed.
    // Expected Result:
    // The test should demonstrate that the system can successfully handle concurrent operations without data corruption.
    // When the owner attempts to close the survey at the same time a participant tries to vote, the system should prioritize transaction order based on block confirmation, typically allowing only the first transaction in order to maintain state consistency.
    // If the survey close action is processed first, subsequent votes should be rejected, ensuring that no votes are accepted after a survey is officially closed, thus preventing state corruption.
    // Security Issue: State Corruption
    // Potential Damage: Inconsistent contract state, unauthorized votes, loss of survey integrity.
    function testStateCorruptionViaSimultaneousActions() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1; options[1] = 2;
        blockPoll.createSurvey("State Corruption Test", options, 50, 10, true);
        uint surveyId = blockPoll.nextSurveyId() - 1;

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();

        // Simultaneously attempt to close the survey and vote
        vm.startPrank(owner);
        vm.roll(block.number + 50); // Right before survey closure
        blockPoll.closeSurvey(surveyId);
        vm.stopPrank();

        vm.startPrank(participant1);
        vm.expectRevert("Survey is closed");
        blockPoll.vote(surveyId, 1);
        vm.stopPrank();
    }
    // Purpose: Ensure staking and unstaking logic works as intended, especially regarding active survey participation.
    // Specification: Users should be able to stake and unstake correctly with respect to their participation in surveys.
    // Expected Result: Unstaking should fail if it reduces the stake below 1 ether while the user is participating in an active survey.
    // Security Issue: Maintaining Minimum Stake Requirement
    // Potential Damage: Participants might unstake too much, causing contract violations and instability.
    function testStakeAndUnstakeLogic() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Stake-Unstake Logic Test", options, 100, 10, true);
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 2 ether}();
        blockPoll.vote(0, 0);
        vm.expectRevert("Must maintain minimum stake due to active survey participation");
        blockPoll.unstakeEther(2 ether);
        blockPoll.unstakeEther(1 ether); // Should succeed
        vm.stopPrank();
    }
    // Purpose: Ensure rewards are distributed correctly based on participation and eligibility for daily bonuses.
    // Specification: Rewards should be correctly calculated and distributed to participants.
    // Expected Result: Rewards should be accurately distributed according to the contract logic.
    // Security issues: Unauthorized actions prevention, Integrity of reward calculation to avoid exploitation
    // Potential damage if the test fails: Financial loss for participants, Loss of trust in the platform, Exploitation by malicious actors
    function testRewardDistributionLogic() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Reward Distribution Test", options, 100, 10, true);
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        blockPoll.vote(0, 0);
        vm.stopPrank();

        vm.startPrank(owner);
        blockPoll.closeSurvey(0);
        vm.stopPrank();

        uint reward = blockPoll.rewardBalances(0, participant1);
        assertGt(reward, 0, "Reward was not distributed correctly");
    }
    // Purpose: Ensure multiple staking transactions are handled correctly.
    // Specification: Users should be able to stake multiple times without issues.
    // Expected Result: Multiple staking transactions should update the user's stake correctly.
    // Security issues: Prevention of double-counting or miscalculation
    // Potential damage if the test fails: Financial loss and confusion for users, Erosion of trust in the platform
    function testMultipleStakingTransactions() public {
        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        blockPoll.stakeEther{value: 2 ether}();
        blockPoll.stakeEther{value: 3 ether}();
        uint totalStake = blockPoll.stakes(participant1);
        assertEq(totalStake, 6 ether, "Total stake is not correct");
        vm.stopPrank();
    }
    // Purpose: Ensure users cannot withdraw rewards if they attempt to vote twice (even if one vote succeeds).
    // Specification: Users should only be able to withdraw rewards for valid participation.
    // Expected Result: Attempting to withdraw rewards after invalid voting attempts should fail.
    // Security issues: Prevent double voting attempts, Ensure rewards are distributed only for valid participation
    // Potential damage if the test fails: Users might exploit the system to vote multiple times, Incorrect reward distribution leading to financial loss
    function testRewardWithdrawalAfterDoubleVoting() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Double Voting Test", options, 100, 10, true);
        uint surveyId = blockPoll.nextSurveyId() - 1;
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        blockPoll.vote(surveyId, 0);
        vm.expectRevert("You can only vote once per survey.");
        blockPoll.vote(surveyId, 1);
        vm.stopPrank();

        vm.startPrank(owner);
        blockPoll.closeSurvey(surveyId);
        vm.stopPrank();

        vm.startPrank(participant1);
        uint reward = blockPoll.rewardBalances(surveyId, participant1);
        assertGt(reward, 0, "Reward was not distributed correctly");
        vm.stopPrank();
    }
    // Purpose: Ensure users cannot unstake ether if they are participating in active surveys and the unstake would bring their balance below 1 ether.
    // Specification: Users must maintain a minimum stake of 1 ether while participating in active surveys.
    // Expected Result: Attempting to unstake below the required amount while participating in active surveys should fail.
    // Security issues: Prevent unstaking below the minimum required balance
    // Potential damage if the test fails: Users could unstake more than allowed, compromising survey integrity
    function testUnstakeMoreThanStakedAmount() public {
        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        vm.expectRevert("Insufficient staked amount");
        blockPoll.unstakeEther(2 ether);
        vm.stopPrank();
    }
    // Purpose: Ensure reward distribution handles the case where there are no participants.
    // Specification: The reward distribution function should not fail if there are no participants.
    // Expected Result: Reward distribution should complete without errors, even if there are no participants.
    // Security issues: Prevent rewards being distributed without participation, Ensure integrity of reward distribution logic
    // Potential damage if the test fails: Unjust reward distribution, leading to financial inconsistencies
    function testRewardDistributionWithoutParticipants() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("No Participants Reward Test", options, 100, 10, true);
        uint surveyId = blockPoll.nextSurveyId() - 1;
        vm.stopPrank();

        // Close survey without any participants
        vm.startPrank(owner);
        blockPoll.closeSurvey(surveyId);
        uint reward = blockPoll.rewardBalances(surveyId, owner);
        assertEq(reward, 0, "Reward should be zero for owner");
        vm.stopPrank();
    }
    // Purpose: Ensure that users can correctly unstake their ether after the survey they participated in is closed.
    // Specification: Users should be able to unstake their ether after the survey is closed.
    // Expected Result: Unstaking should succeed after the survey closure, provided the user has no other active surveys.
    // Security issues: Ensure correct refund of staked ether after survey ends
    // Potential damage if the test fails: Participants might not get their staked ether back, leading to financial loss
    function testStakeRefundAfterSurveyClosure() public {
        vm.startPrank(owner);
        blockPoll.register("Owner");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        blockPoll.createSurvey("Stake Refund Test", options, 100, 10, true);
        uint surveyId = blockPoll.nextSurveyId() - 1;
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.stakeEther{value: 1 ether}();
        blockPoll.vote(surveyId, 0);
        vm.stopPrank();

        vm.startPrank(owner);
        blockPoll.closeSurvey(surveyId);
        vm.stopPrank();

        vm.startPrank(participant1);
        blockPoll.unstakeEther(1 ether);
        uint remainingStake = blockPoll.stakes(participant1);
        assertEq(remainingStake, 0, "Stake was not refunded correctly");
        vm.stopPrank();
    }
}   

// Helper contract to simulate a reentrancy attack
contract AttackContract {
    BlockPoll public blockPoll;
    uint public surveyId;

    constructor(BlockPoll _blockPoll, uint _surveyId) {
        blockPoll = _blockPoll;
        surveyId = _surveyId;
    }

    function attack() public payable {
        blockPoll.withdrawReward(surveyId);
    }

    receive() external payable {
        if (address(blockPoll).balance >= 0.1 ether) {
            blockPoll.withdrawReward(surveyId);
        }
    }
}

// Helper contract to simulate a reentrancy attack on unstakeEther function
contract ReentrancyAttackContract {
    BlockPoll public blockPoll;

    constructor(BlockPoll _blockPoll) {
        blockPoll = _blockPoll;
    }

    function attack() public payable {
        blockPoll.unstakeEther(msg.value);
    }

    receive() external payable {
        if (address(blockPoll).balance >= 0.1 ether) {
            blockPoll.unstakeEther(0.1 ether);
        }
    }
}


