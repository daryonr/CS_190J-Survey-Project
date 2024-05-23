// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BlockPoll {
    struct Survey 
    {
        string description; // Descriptive text for the survey
        uint[] options; // Array of numerical options for the survey

        address owner; // Address of the user who created the survey
        mapping(uint => uint) results; // Mapping from option index to count of votes
        mapping(address => bool) hasVoted; // Tracks whether an address has voted in this survey

        uint maxDataPoints; // Maximum number of votes (data points) accepted for the survey
        uint dataCount; // Current count of data points collected

        uint expiryBlock; // Not sure how to use this
        bool isOpen; // check if the survey is still open for responses
    }

    // Mapping from survey ID to Survey struct, storing all surveys
    mapping(uint => Survey) public surveys;

    // Mapping from user address to a custom user name
    mapping(address => string) public userNames;

    // ID to track and assign to the next survey created
    uint public nextSurveyId;

    // Register a user with a custom name
    function register(string calldata userName) external 
    {
        ...
    }

    // Create a new survey
    function createSurvey(string calldata description, uint[] calldata options, uint durationInBlocks, uint maxDataPoints) external 
    {
        ...
    }

    // Vote in a survey
    function vote(uint surveyId, uint optionIndex) external 
    {
        ...
    }

    // Manually close a survey
    function closeSurvey(uint surveyId) public 
    {
        ...
    }

    // Function to claim rewards
    function claimRewards(uint surveyId) external 
    {
        ...
    }

    // Payout func
    receive() external payable 
    {

    }
}
