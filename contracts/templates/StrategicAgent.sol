// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title StrategicAgent
 * @dev Enhanced template for strategic agents with learning capabilities
 */
contract StrategicAgent is Ownable {
    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // The address of the data feed
    address public dataFeed;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // The monitoring configuration
    struct MonitoringConfig {
        string[] keywords;
        string[] accounts;
        string[] topics;
        uint256 alertThreshold;
        uint256 scanFrequency;
        bool alertsEnabled;
        // Enhanced learning parameters
        uint256 learningThreshold;
        bool adaptiveMonitoring;
        uint256 confidenceRequirement;
    }

    // The monitoring configuration
    MonitoringConfig public config;

    // The alert history
    struct Alert {
        uint256 id;
        string alertType; // "mention", "trend", "sentiment", etc.
        string source;
        string content;
        int256 sentiment;
        uint256 timestamp;
        bool acknowledged;
        // Learning enhancements
        uint256 confidenceScore;
        bool learningTriggered;
        bytes32 learningHash;
    }

    // The alert history
    mapping(uint256 => Alert) public alertHistory;
    uint256 public alertCount;

    // The trend analysis
    struct TrendAnalysis {
        uint256 id;
        string topic;
        int256 sentiment;
        uint256 volume;
        uint256 timestamp;
        string summary;
        // Learning enhancements
        uint256 accuracyScore;
        bool validated;
        bytes32 predictionHash;
    }

    // The trend analysis history
    mapping(uint256 => TrendAnalysis) public trendAnalysisHistory;
    uint256 public trendAnalysisCount;

    // The sentiment analysis
    struct SentimentAnalysis {
        int256 overallSentiment;
        uint256 positiveCount;
        uint256 neutralCount;
        uint256 negativeCount;
        uint256 lastUpdated;
        // Learning enhancements
        uint256 confidenceLevel;
        uint256 learningIterations;
        int256 predictedTrend;
    }

    // The sentiment analysis for each keyword
    mapping(string => SentimentAnalysis) public keywordSentiment;

    // Learning-specific data structures
    struct LearningInsight {
        uint256 id;
        string insightType; // "pattern", "correlation", "prediction"
        string description;
        uint256 confidence;
        uint256 timestamp;
        bool validated;
        uint256 validationScore;
    }

    // Learning insights generated by the agent
    mapping(uint256 => LearningInsight) public learningInsights;
    uint256 public insightCount;

    // Adaptive thresholds based on learning
    mapping(string => uint256) public adaptiveThresholds;

    // Performance metrics for learning validation
    struct PerformanceMetrics {
        uint256 totalPredictions;
        uint256 correctPredictions;
        uint256 falsePositives;
        uint256 falseNegatives;
        uint256 lastCalculated;
    }

    PerformanceMetrics public performanceMetrics;

    // Event emitted when an alert is triggered
    event AlertTriggered(
        uint256 indexed alertId,
        string alertType,
        string source,
        uint256 confidence
    );

    // Event emitted when a trend analysis is completed
    event TrendAnalysisCompleted(
        uint256 indexed analysisId,
        string topic,
        int256 sentiment,
        uint256 accuracy
    );

    // Event emitted when the monitoring configuration is updated
    event MonitoringConfigUpdated(string[] keywords, string[] accounts, string[] topics);

    // Learning-specific events
    event LearningInsightGenerated(
        uint256 indexed insightId,
        string insightType,
        uint256 confidence
    );
    event LearningThresholdAdapted(string parameter, uint256 oldValue, uint256 newValue);
    event PerformanceMetricsUpdated(uint256 accuracy, uint256 totalPredictions);
    event LearningModuleUpdated(address indexed oldModule, address indexed newModule);

    /**
     * @dev Initializes the contract with enhanced learning capabilities
     * @param _agentToken The address of the BEP007 token
     * @param _dataFeed The address of the data feed
     * @param _keywords The keywords to monitor
     * @param _accounts The accounts to monitor
     * @param _topics The topics to monitor
     * @param _learningModule The address of the learning module (optional)
     */
    constructor(
        address _agentToken,
        address _dataFeed,
        string[] memory _keywords,
        string[] memory _accounts,
        string[] memory _topics,
        address _learningModule
    ) {
        require(_agentToken != address(0), "StrategicAgent: agent token is zero address");

        agentToken = _agentToken;
        dataFeed = _dataFeed;
        learningModule = _learningModule;
        learningEnabled = _learningModule != address(0);

        config = MonitoringConfig({
            keywords: _keywords,
            accounts: _accounts,
            topics: _topics,
            alertThreshold: 70, // Default threshold (70%)
            scanFrequency: 3600, // Default scan frequency (1 hour)
            alertsEnabled: true,
            learningThreshold: 80, // Learning activation threshold
            adaptiveMonitoring: learningEnabled,
            confidenceRequirement: 75 // Minimum confidence for actions
        });

        // Initialize performance metrics
        performanceMetrics = PerformanceMetrics({
            totalPredictions: 0,
            correctPredictions: 0,
            falsePositives: 0,
            falseNegatives: 0,
            lastCalculated: block.timestamp
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "StrategicAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(
            learningEnabled && learningModule != address(0),
            "StrategicAgent: learning not enabled"
        );
        _;
    }

    /**
     * @dev Updates the learning module
     * @param _newLearningModule The address of the new learning module
     */
    function updateLearningModule(address _newLearningModule) external onlyOwner {
        address oldModule = learningModule;
        learningModule = _newLearningModule;
        learningEnabled = _newLearningModule != address(0);

        // Update adaptive monitoring based on learning availability
        config.adaptiveMonitoring = learningEnabled;

        emit LearningModuleUpdated(oldModule, _newLearningModule);
    }

    /**
     * @dev Updates the monitoring configuration with learning enhancements
     * @param _keywords The keywords to monitor
     * @param _accounts The accounts to monitor
     * @param _topics The topics to monitor
     * @param _alertThreshold The alert threshold
     * @param _scanFrequency The scan frequency
     * @param _alertsEnabled Whether alerts are enabled
     * @param _learningThreshold The learning activation threshold
     * @param _adaptiveMonitoring Whether adaptive monitoring is enabled
     * @param _confidenceRequirement The minimum confidence requirement
     */
    function updateMonitoringConfig(
        string[] memory _keywords,
        string[] memory _accounts,
        string[] memory _topics,
        uint256 _alertThreshold,
        uint256 _scanFrequency,
        bool _alertsEnabled,
        uint256 _learningThreshold,
        bool _adaptiveMonitoring,
        uint256 _confidenceRequirement
    ) external onlyOwner {
        require(_alertThreshold <= 100, "StrategicAgent: alert threshold must be <= 100");
        require(_learningThreshold <= 100, "StrategicAgent: learning threshold must be <= 100");
        require(
            _confidenceRequirement <= 100,
            "StrategicAgent: confidence requirement must be <= 100"
        );

        config = MonitoringConfig({
            keywords: _keywords,
            accounts: _accounts,
            topics: _topics,
            alertThreshold: _alertThreshold,
            scanFrequency: _scanFrequency,
            alertsEnabled: _alertsEnabled,
            learningThreshold: _learningThreshold,
            adaptiveMonitoring: _adaptiveMonitoring && learningEnabled,
            confidenceRequirement: _confidenceRequirement
        });

        emit MonitoringConfigUpdated(_keywords, _accounts, _topics);
    }

    /**
     * @dev Records an alert with learning integration
     * @param _alertType The type of alert
     * @param _source The source of the alert
     * @param _content The content of the alert
     * @param _sentiment The sentiment of the alert
     * @param _confidence The confidence score of the alert
     */
    function recordAlert(
        string memory _alertType,
        string memory _source,
        string memory _content,
        int256 _sentiment,
        uint256 _confidence
    ) external onlyAgentToken {
        require(config.alertsEnabled, "StrategicAgent: alerts are disabled");
        require(_confidence <= 100, "StrategicAgent: confidence must be <= 100");

        alertCount += 1;

        bool shouldTriggerLearning = learningEnabled && _confidence >= config.learningThreshold;
        bytes32 learningHash = bytes32(0);

        if (shouldTriggerLearning) {
            learningHash = keccak256(
                abi.encodePacked(_alertType, _source, _content, block.timestamp)
            );
            _recordLearningInteraction("alert_generation", true);
        }

        alertHistory[alertCount] = Alert({
            id: alertCount,
            alertType: _alertType,
            source: _source,
            content: _content,
            sentiment: _sentiment,
            timestamp: block.timestamp,
            acknowledged: false,
            confidenceScore: _confidence,
            learningTriggered: shouldTriggerLearning,
            learningHash: learningHash
        });

        emit AlertTriggered(alertCount, _alertType, _source, _confidence);

        // Adaptive threshold adjustment based on learning
        if (config.adaptiveMonitoring && shouldTriggerLearning) {
            _adaptThreshold(_alertType, _confidence);
        }
    }

    /**
     * @dev Records a trend analysis with learning validation
     * @param _topic The topic of the analysis
     * @param _sentiment The sentiment of the analysis
     * @param _volume The volume of the analysis
     * @param _summary The summary of the analysis
     * @param _accuracyScore The predicted accuracy score
     */
    function recordTrendAnalysis(
        string memory _topic,
        int256 _sentiment,
        uint256 _volume,
        string memory _summary,
        uint256 _accuracyScore
    ) external onlyAgentToken {
        require(_accuracyScore <= 100, "StrategicAgent: accuracy score must be <= 100");

        trendAnalysisCount += 1;

        bytes32 predictionHash = keccak256(
            abi.encodePacked(_topic, _sentiment, _volume, block.timestamp)
        );

        trendAnalysisHistory[trendAnalysisCount] = TrendAnalysis({
            id: trendAnalysisCount,
            topic: _topic,
            sentiment: _sentiment,
            volume: _volume,
            timestamp: block.timestamp,
            summary: _summary,
            accuracyScore: _accuracyScore,
            validated: false,
            predictionHash: predictionHash
        });

        // Record learning interaction
        if (learningEnabled) {
            _recordLearningInteraction("trend_analysis", true);
        }

        // Update performance metrics
        performanceMetrics.totalPredictions += 1;

        emit TrendAnalysisCompleted(trendAnalysisCount, _topic, _sentiment, _accuracyScore);
    }

    /**
     * @dev Validates a trend analysis prediction
     * @param _analysisId The ID of the analysis to validate
     * @param _actualOutcome Whether the prediction was correct
     * @param _validationScore The validation score (0-100)
     */
    function validateTrendAnalysis(
        uint256 _analysisId,
        bool _actualOutcome,
        uint256 _validationScore
    ) external onlyOwner {
        require(
            _analysisId <= trendAnalysisCount && _analysisId > 0,
            "StrategicAgent: analysis does not exist"
        );
        require(_validationScore <= 100, "StrategicAgent: validation score must be <= 100");

        TrendAnalysis storage analysis = trendAnalysisHistory[_analysisId];
        require(!analysis.validated, "StrategicAgent: analysis already validated");

        analysis.validated = true;

        // Update performance metrics
        if (_actualOutcome) {
            performanceMetrics.correctPredictions += 1;
        } else {
            if (_validationScore < 50) {
                performanceMetrics.falsePositives += 1;
            } else {
                performanceMetrics.falseNegatives += 1;
            }
        }

        performanceMetrics.lastCalculated = block.timestamp;

        // Record learning interaction
        if (learningEnabled) {
            _recordLearningInteraction("prediction_validation", _actualOutcome);
        }

        emit PerformanceMetricsUpdated(
            _getAccuracyPercentage(),
            performanceMetrics.totalPredictions
        );
    }

    /**
     * @dev Generates a learning insight
     * @param _insightType The type of insight
     * @param _description The description of the insight
     * @param _confidence The confidence level of the insight
     */
    function generateLearningInsight(
        string memory _insightType,
        string memory _description,
        uint256 _confidence
    ) external onlyAgentToken whenLearningEnabled {
        require(_confidence <= 100, "StrategicAgent: confidence must be <= 100");
        require(
            _confidence >= config.confidenceRequirement,
            "StrategicAgent: confidence below requirement"
        );

        insightCount += 1;

        learningInsights[insightCount] = LearningInsight({
            id: insightCount,
            insightType: _insightType,
            description: _description,
            confidence: _confidence,
            timestamp: block.timestamp,
            validated: false,
            validationScore: 0
        });

        emit LearningInsightGenerated(insightCount, _insightType, _confidence);
    }

    /**
     * @dev Updates sentiment with enhanced learning integration
     * @param _keyword The keyword
     * @param _sentiment The sentiment value (-100 to 100)
     * @param _isPositive Whether the sentiment is positive
     * @param _isNeutral Whether the sentiment is neutral
     * @param _isNegative Whether the sentiment is negative
     * @param _confidence The confidence level of the sentiment analysis
     */
    function updateSentiment(
        string memory _keyword,
        int256 _sentiment,
        bool _isPositive,
        bool _isNeutral,
        bool _isNegative,
        uint256 _confidence
    ) external onlyAgentToken {
        require(
            _sentiment >= -100 && _sentiment <= 100,
            "StrategicAgent: sentiment must be between -100 and 100"
        );
        require(_confidence <= 100, "StrategicAgent: confidence must be <= 100");

        SentimentAnalysis storage analysis = keywordSentiment[_keyword];

        // Update counts
        if (_isPositive) {
            analysis.positiveCount += 1;
        } else if (_isNeutral) {
            analysis.neutralCount += 1;
        } else if (_isNegative) {
            analysis.negativeCount += 1;
        }

        // Update overall sentiment (weighted average)
        uint256 totalCount = analysis.positiveCount +
            analysis.neutralCount +
            analysis.negativeCount;

        if (totalCount == 1) {
            // First entry
            analysis.overallSentiment = _sentiment;
            analysis.confidenceLevel = _confidence;
        } else {
            // Weighted average
            analysis.overallSentiment =
                (analysis.overallSentiment * int256(totalCount - 1) + _sentiment) /
                int256(totalCount);
            analysis.confidenceLevel =
                (analysis.confidenceLevel * (totalCount - 1) + _confidence) /
                totalCount;
        }

        analysis.lastUpdated = block.timestamp;

        // Learning enhancements
        if (learningEnabled && _confidence >= config.learningThreshold) {
            analysis.learningIterations += 1;

            // Generate predicted trend based on learning
            if (analysis.learningIterations >= 5) {
                analysis.predictedTrend = _calculatePredictedTrend(analysis);
            }
        }
    }

    /**
     * @dev Gets the current accuracy percentage
     * @return The accuracy percentage
     */
    function getAccuracyPercentage() external view returns (uint256) {
        return _getAccuracyPercentage();
    }

    /**
     * @dev Gets learning insights
     * @param _count The number of insights to return
     * @return An array of recent learning insights
     */
    function getRecentLearningInsights(
        uint256 _count
    ) external view returns (LearningInsight[] memory) {
        uint256 resultCount = _count > insightCount ? insightCount : _count;
        LearningInsight[] memory insights = new LearningInsight[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            insights[i] = learningInsights[insightCount - i];
        }

        return insights;
    }

    /**
     * @dev Gets the adaptive threshold for a parameter
     * @param _parameter The parameter name
     * @return The adaptive threshold value
     */
    function getAdaptiveThreshold(string memory _parameter) external view returns (uint256) {
        return adaptiveThresholds[_parameter];
    }

    /**
     * @dev Gets performance metrics
     * @return The current performance metrics
     */
    function getPerformanceMetrics() external view returns (PerformanceMetrics memory) {
        return performanceMetrics;
    }

    /**
     * @dev Internal function to record learning interactions
     * @param _interactionType The type of interaction
     * @param _success Whether the interaction was successful
     */
    function _recordLearningInteraction(
        string memory _interactionType,
        bool _success
    ) internal whenLearningEnabled {
        try
            ILearningModule(learningModule).recordInteraction(
                uint256(uint160(agentToken)), // Use agent token address as token ID
                _interactionType,
                _success
            )
        {} catch {
            // Silently fail to not break agent functionality
        }
    }

    /**
     * @dev Internal function to adapt thresholds based on learning
     * @param _parameter The parameter to adapt
     * @param _currentValue The current value
     */
    function _adaptThreshold(string memory _parameter, uint256 _currentValue) internal {
        uint256 oldThreshold = adaptiveThresholds[_parameter];
        uint256 newThreshold;

        // Simple adaptive algorithm - can be enhanced with more sophisticated ML
        if (_getAccuracyPercentage() > 80) {
            // High accuracy - can be more sensitive
            newThreshold = oldThreshold > 5 ? oldThreshold - 5 : 0;
        } else if (_getAccuracyPercentage() < 60) {
            // Low accuracy - be more conservative
            newThreshold = oldThreshold + 5;
            if (newThreshold > 100) newThreshold = 100;
        } else {
            // Maintain current threshold
            newThreshold = oldThreshold;
        }

        if (newThreshold != oldThreshold) {
            adaptiveThresholds[_parameter] = newThreshold;
            emit LearningThresholdAdapted(_parameter, oldThreshold, newThreshold);
        }
    }

    /**
     * @dev Internal function to calculate predicted trend
     * @param _analysis The sentiment analysis data
     * @return The predicted trend
     */
    function _calculatePredictedTrend(
        SentimentAnalysis memory _analysis
    ) internal pure returns (int256) {
        // Simple trend prediction based on sentiment momentum
        // In a real implementation, this would use more sophisticated algorithms
        if (_analysis.positiveCount > _analysis.negativeCount * 2) {
            return 1; // Positive trend
        } else if (_analysis.negativeCount > _analysis.positiveCount * 2) {
            return -1; // Negative trend
        } else {
            return 0; // Neutral trend
        }
    }

    /**
     * @dev Internal function to get accuracy percentage
     * @return The accuracy percentage
     */
    function _getAccuracyPercentage() internal view returns (uint256) {
        if (performanceMetrics.totalPredictions == 0) {
            return 0;
        }

        return (performanceMetrics.correctPredictions * 100) / performanceMetrics.totalPredictions;
    }

    // ... (Include remaining functions from original implementation with learning enhancements)

    /**
     * @dev Acknowledges an alert
     * @param _alertId The ID of the alert
     */
    function acknowledgeAlert(uint256 _alertId) external onlyOwner {
        require(_alertId <= alertCount && _alertId > 0, "StrategicAgent: alert does not exist");

        alertHistory[_alertId].acknowledged = true;

        // Record learning interaction if learning was triggered for this alert
        if (alertHistory[_alertId].learningTriggered && learningEnabled) {
            _recordLearningInteraction("alert_acknowledgment", true);
        }
    }

    /**
     * @dev Gets the monitoring configuration
     * @return The monitoring configuration
     */
    function getMonitoringConfig() external view returns (MonitoringConfig memory) {
        return config;
    }

    /**
     * @dev Gets the recent alerts
     * @param _count The number of alerts to return
     * @return An array of recent alerts
     */
    function getRecentAlerts(uint256 _count) external view returns (Alert[] memory) {
        uint256 resultCount = _count > alertCount ? alertCount : _count;
        Alert[] memory alerts = new Alert[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            alerts[i] = alertHistory[alertCount - i];
        }

        return alerts;
    }

    /**
     * @dev Gets the recent trend analyses
     * @param _count The number of analyses to return
     * @return An array of recent trend analyses
     */
    function getRecentTrendAnalyses(uint256 _count) external view returns (TrendAnalysis[] memory) {
        uint256 resultCount = _count > trendAnalysisCount ? trendAnalysisCount : _count;
        TrendAnalysis[] memory analyses = new TrendAnalysis[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            analyses[i] = trendAnalysisHistory[trendAnalysisCount - i];
        }

        return analyses;
    }

    /**
     * @dev Gets the sentiment analysis for a keyword
     * @param _keyword The keyword
     * @return The sentiment analysis
     */
    function getKeywordSentiment(
        string memory _keyword
    ) external view returns (SentimentAnalysis memory) {
        return keywordSentiment[_keyword];
    }

    /**
     * @dev Gets the overall sentiment across all keywords
     * @return The overall sentiment
     */
    function getOverallSentiment() external view returns (int256) {
        int256 totalSentiment = 0;
        uint256 keywordCount = 0;

        for (uint256 i = 0; i < config.keywords.length; i++) {
            SentimentAnalysis storage analysis = keywordSentiment[config.keywords[i]];

            if (analysis.lastUpdated > 0) {
                totalSentiment += analysis.overallSentiment;
                keywordCount++;
            }
        }

        if (keywordCount == 0) {
            return 0;
        }

        return totalSentiment / int256(keywordCount);
    }

    /**
     * @dev Checks if an alert should be triggered based on sentiment and learning
     * @param _sentiment The sentiment value
     * @param _confidence The confidence level
     * @return Whether an alert should be triggered
     */
    function shouldTriggerAlert(
        int256 _sentiment,
        uint256 _confidence
    ) external view returns (bool) {
        if (!config.alertsEnabled) {
            return false;
        }

        // Convert sentiment to absolute value for threshold comparison
        uint256 sentimentAbs = _sentiment < 0 ? uint256(-_sentiment) : uint256(_sentiment);

        // Use adaptive threshold if available and learning is enabled
        uint256 threshold = config.alertThreshold;
        if (config.adaptiveMonitoring && adaptiveThresholds["alert"] > 0) {
            threshold = adaptiveThresholds["alert"];
        }

        return sentimentAbs >= threshold && _confidence >= config.confidenceRequirement;
    }
}
