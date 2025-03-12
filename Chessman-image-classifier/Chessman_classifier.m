%% Load and Prepare Dataset
datasetPath = 'C:\Users\mmaji\ETE\EDGE_COURSE_MATLAB\machine learning\CNN\Chessman-image-classifier\chess_dataset';
imds = imageDatastore(datasetPath, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames');

% Display detected classes
numClasses = numel(categories(imds.Labels));
disp(['Detected ', num2str(numClasses), ' classes']);

% Ensure balanced splitting for 600 images
[imdsTrain, imdsVal] = splitEachLabel(imds, 0.8, 0.2, 'randomized');

%% Data Augmentation Setup
targetSize = [224 224 3]; % Define image size explicitly

augmenter = imageDataAugmenter(...
    'RandRotation', [-20 20], ...  % Slightly reduced rotation
    'RandScale', [0.8 1.2], ...
    'RandXTranslation', [-25 25], ...
    'RandYTranslation', [-25 25], ...
    'RandXShear', [-15 15], ...
    'RandYShear', [-15 15], ...
    'RandXReflection', true, ...
    'RandYReflection', false);  % Reduced unnecessary transformations

augimdsTrain = augmentedImageDatastore(targetSize, imdsTrain, ...
    'DataAugmentation', augmenter, ...
    'ColorPreprocessing', 'gray2rgb');

augimdsVal = augmentedImageDatastore(targetSize, imdsVal, ...
    'ColorPreprocessing', 'gray2rgb');

%% CNN Architecture
layers = [
    imageInputLayer(targetSize, 'Name', 'input')

    convolution2dLayer(3, 32, 'Padding','same', 'Name','conv1')
    batchNormalizationLayer('Name','bn1')
    reluLayer('Name','relu1')
    maxPooling2dLayer(2, 'Stride',2, 'Name','pool1')

    convolution2dLayer(3, 64, 'Padding','same', 'Name','conv2')
    batchNormalizationLayer('Name','bn2')
    reluLayer('Name','relu2')
    maxPooling2dLayer(2, 'Stride',2, 'Name','pool2')

    convolution2dLayer(3, 128, 'Padding','same', 'Name','conv3')
    batchNormalizationLayer('Name','bn3')
    reluLayer('Name','relu3')
    maxPooling2dLayer(2, 'Stride',2, 'Name','pool3')

    convolution2dLayer(3, 256, 'Padding','same', 'Name','conv4')
    batchNormalizationLayer('Name','bn4')
    reluLayer('Name','relu4')
    maxPooling2dLayer(2, 'Stride',2, 'Name','pool4')

    globalAveragePooling2dLayer('Name','gap')

    dropoutLayer(0.4, 'Name','drop1') 
    fullyConnectedLayer(512, 'Name','fc1') 
    reluLayer('Name','relu5')
    dropoutLayer(0.3, 'Name','drop2')

    fullyConnectedLayer(numClasses, 'Name','fc_final')
    softmaxLayer('Name','softmax')
    classificationLayer('Name','output')];

%% Training Configuration
numTraining = numel(imdsTrain.Files);
validationFrequency = max(1, floor(numTraining / 10)); 

options = trainingOptions('adam', ...
    'InitialLearnRate', 0.0003, ... % Slightly increased LR for efficiency
    'MaxEpochs', 25, ...
    'MiniBatchSize', 16, ... % Reduced to fit small dataset
    'ValidationData', augimdsVal, ...
    'ValidationFrequency', validationFrequency, ...
    'Shuffle', 'every-epoch', ...
    'Plots', 'training-progress', ...
    'Verbose', true, ...
    'L2Regularization', 0.0005, ... 
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropPeriod', 10, ...
    'LearnRateDropFactor', 0.5);

%% Train the Model
[net, trainInfo] = trainNetwork(augimdsTrain, layers, options);

%% Evaluate Model Performance
[YPred, scores] = classify(net, augimdsVal);
YVal = imdsVal.Labels;

[confMat, order] = confusionmat(YVal, YPred);
precision = diag(confMat) ./ sum(confMat, 2);
recall = diag(confMat) ./ sum(confMat, 1)';
f1 = 2 * (precision .* recall) ./ (precision + recall);

% Display evaluation metrics
disp('Class-wise Metrics:');
disp(table(order, precision, recall, f1, ...
    'VariableNames', {'Class', 'Precision', 'Recall', 'F1-Score'}));

% Save trained model
save('chessman_classifier_model.mat', 'net', 'trainInfo', 'confMat');
