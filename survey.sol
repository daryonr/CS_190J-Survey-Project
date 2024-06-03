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
        mapping(address => uint) lastVoteTimestamp; // Tracks the timestamp of the last vote for each user

        uint maxDataPoints; // Maximum number of votes (data points) accepted for the survey
        uint dataCount; // Current count of data points collected

        uint expiryBlock; // Not sure how to use this
        bool isOpen; // check if the survey is still open for responses
        bool allowPublicResults; // Allow viewing results after the survey has closed
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
        require(bytes(userNames[msg.sender]).length == 0, "Username already taken");
        userNames[msg.sender] = userName;
    }

    // Create a new survey
    function createSurvey(string calldata description, uint[] calldata options, uint durationInBlocks, uint maxDataPoints, bool publicResults) external 
    {
        require(bytes(userNames[msg.sender]).length > 0, "Registration required to create surveys");
        uint surveyId = nextSurveyId++;
        Survey storage newSurvey = surveys[surveyId];
        newSurvey.description = description;
        newSurvey.options = options;
        newSurvey.expiryBlock = block.number + durationInBlocks;
        newSurvey.maxDataPoints = maxDataPoints;
        newSurvey.owner = msg.sender;
        newSurvey.isOpen = true;
        newSurvey.publicResults =publicResults;
    }

    // Vote in a survey
    function vote(uint surveyId, uint optionIndex) external 
    {
        Survey storage survey = surveys[surveyId];
        require(survey.dataCount < survey.maxDataPoints, "Maximum answers reached");
        require(survey.isOpen == true, "Survey is closed");
        require(survey.hasVoted[msg.sender] == false, "You can only vote once.");
        survey.results[optionIndex] += 1;
        survey.dataCount += 1;
        survey.hasVoted[msg.sender] = true;
        if (survey.dataCount == survey.maxDataPoints)
        {
            closeSurvey(surveyId);
        }
    }

    // Close a survey
    function closeSurvey(uint surveyId) public 
    {
        Survey storage survey = surveys[surveyId];
        require(msg.sender == survey.owner || survey.dataCount == survey.maxDataPoints || 
                block.number >= survey.expiryBlock, "Cannot close survey yet");
        if (survey.isOpen) {
            survey.isOpen = false;
            distributeRewards(surveyId);
        }
    }

    // Function to distribute rewards
    function distributeRewards(uint surveyId) external 
    {
        ...
    }

    // Payout func
    receive() external payable 
    {

    }
}
