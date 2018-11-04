% Script to remove PHI from Humphrey Visual Field XML files
%
% Description:
%   Goes here
%
%

%% Variable declaration
% Root paths to directory of HFA results in raw XML form
rootPathsToHFAData = {'/Volumes/Aguirre/HFA 750-42254 SEI 5th Floor/', ...
    '/Volumes/Aguirre/HFA 750-50072 Mercy Fitz', ...
    '/Volumes/Aguirre/HFA 750-50440 PCAM Ophtho', ...
    '/Volumes/Aguirre/5th floor'};
databasePath = 2;                         % Select which data base from the above list you want to analyze
savePath = 'Anonymized field data';       % Specify the name of the folder you want to save the anonymized data to. This folder should be place within the "Aguirre" server to protect the key
over_count = 1;                           % Specify which position in the database you wish to start with. Default to 1, but can be moved if you want to skip some files
anonymized_ID_header = 'CB_';             % Specify a label for save filename. Can be changed from 'CB' for other studies

%% Mass raw data read in and sort
addpath(savePath);
filename = 'HVFMasterList.mat';           % Specify the name you wish to use for the Master Key. Name is hard coded into the save command on line 150

% Determine if the Key has already been created. Load the Key if yes,
% create a new variable if no
% Current column (1-3) are hard coded at lines 77, 78 and 137
% Column 1 = MRN           
% Column 2 = Key ID #       
% Column 3 = # of fields    
if exist(filename,'file')
    load(filename)
else
    HVFMasterList = [];
end

% CD into the database and load the list of file names
cd(rootPathsToHFAData{databasePath});
s = dir;

while over_count < length(dir)-1                                % Loops through the entire loaded directory
    while over_count < length(dir)-1                            % Allows for break commands to skip non-.xml files
        
        patient_count = size(HVFMasterList,1);                  % Check the size of the Key to detemine how many patients have been processed so far. This will be used to assign a new number to new patients
        [filepath,name,ext] = fileparts(s(over_count).name);    % Load the parts of the file name for the currently selected file in the database
        tf = strcmp(ext,'.xml');                                % Determine if the currently selected file is a .xml file
        if tf == 0                                              % Skip this file if it is not an .xml
            over_count = over_count + 1;                        % Increase the loops position in the file list
            clearvars -except over_count s h HVFMasterList savePath databasePath rootPathsToHFAData anonymized_ID_header % Remove all variables not required for running the script
            break;
        end
        patient_code = [];                                      % Initialize anonymized patient ID variable
        new_subject = [];                                       % Initialize variable to track new/recurring subject
        
        %% Load raw data, convert to data structure, generate appropriate directories
        data = xml2struct(s(over_count).name);                  % Load the selected .xml file and convert to a structure
        cd ..                                                   % Move out of the database back to the overarching server   
        cd(savePath);                                           % Move into the save directory
        patient_MRN = data.HFA_EXPORT.PATIENT.PATIENT_ID.Text;  % Identify the MRN used in this test
        exam_date = data.HFA_EXPORT.PATIENT.STUDY.VISIT_DATE.Text; % Identify the date of the test
        
        % Determine if the loaded field is from a pre-existing patient or a
        % new patient.
        % If new patient:
        %   initialize the number of fields count at 1
        %   Assign a new anonymized patient ID code
        % If recurring patient:
        %   Load the previously recorded number of fields and increase
        %   count by 1
        %   Load the previously recorded anonymized patient ID code
        if size(HVFMasterList,1) == 0                               % Skips comparison if this is the first recorded patient
            patient_count = patient_count + 1;
            new_subject = 1;
            ID_number_digits = numel(num2str(patient_count));
            for i = 1 + ID_number_digits:5
                patient_code = strcat(patient_code,'0');
            end
            Num_of_fields = 1;
        elseif find(HVFMasterList(:,1) == str2double(patient_MRN))  % Recurring patient
            patient_count = HVFMasterList((find(HVFMasterList(:,1)==str2double(patient_MRN))),2);
            ID_number_digits = numel(num2str(patient_count));
            for i = 1 + ID_number_digits:5
                patient_code = strcat(patient_code,'0');
            end
        else                                                        % New patient
            patient_count = patient_count + 1;
            new_subject = 1;
            ID_number_digits = numel(num2str(patient_count));
            for i = 1 + ID_number_digits:5
                patient_code = strcat(patient_code,'0');
            end
            Num_of_fields = 1;
        end
        
        % Example patient code: CB_00231. Standardized name up to 99,999
        % unique IDs. Larger numbers can be handled but increast the size
        % ID by one or more characters. Example: CB_100001
        patient_code = strcat(anonymized_ID_header,patient_code,num2str(patient_count));
        
        folder = exist(patient_code,'file'); % Determine if a folder for the given patient ID already exists
        if folder ~= 7                       % If no folder exists, create one
            mkdir(patient_code);
        end
        cd(patient_code);                    % CD into the patient folder
        
        clear folder
        folder = exist(exam_date,'file');    % Determine if,for a given patient, a folder exists for the given visit date
        if folder ~= 7                       % If not folder exists, create one
            mkdir(exam_date) 
        end
        cd(exam_date)                        % CD into the exam date folder
        clear folder
        
        %% Remove identifying information
        data.HFA_EXPORT.PATIENT.LAST_NAME               = [];
        data.HFA_EXPORT.PATIENT.GIVEN_NAME              = [];
        data.HFA_EXPORT.PATIENT.MIDDLE_NAME             = [];
        data.HFA_EXPORT.PATIENT.NAME_PREFIX             = [];
        data.HFA_EXPORT.PATIENT.NAME_SUFFIX             = [];
        data.HFA_EXPORT.PATIENT.FULL_NAME               = [];
        data.HFA_EXPORT.PATIENT.PATIENT_ID              = [];
        data.HFA_EXPORT.PATIENT.BIRTH_DATE              = [];    

        %% Save all remaining variables to matlab file
        % Determine which eye was tested by checking where the blindspot
        % was recorded
%         if str2double(data.HFA_EXPORT.PATIENT.STUDY.SERIES.FIELD_EXAM.STATIC_TEST.BLIND_SPOT_X.Text) > 0
%             which_eye = 'OD_';
%         else
%             which_eye = 'OS_';
%         end 
        
        % If the current subject is new, add them to the Master Key. If
        % they are recurring, increase the field count for the previously
        % recorded entry
        if new_subject
            HVFMasterList = [HVFMasterList;str2double(patient_MRN), patient_count, Num_of_fields];
        else
            HVFMasterList(find(HVFMasterList(:,1)==str2double(patient_MRN)),3) = HVFMasterList(find(HVFMasterList(:,1)==str2double(patient_MRN)),3)+1;
        end
        
        % Save the now anonymized data structure as a .mat file to the exam
        % date for the given subject. 
        % Example file name:
        % OD_CB_00001_raw_field_2018-10-31T12:51:45.mat
        % File name structure
        % TestedEye_Header_PatientCount_raw_field_Date_Time.mat
        save(strcat(patient_code,'_raw_field_',data.HFA_EXPORT.PATIENT.STUDY.SERIES.SERIES_DATE_TIME.Text),'data')
        cd ..  % Move out of the exam date folder into patient folder
        cd ..  % Move out of the patient folder to the save directory
        clearvars -except over_count s h HVFMasterList savePath databasePath rootPathsToHFAData anonymized_ID_header % Remove all variables not required for running the script
        save HVFMasterList HVFMasterList % Save and update the Master Key within the save directory
        cd ..  % Move from save directory to the server
        cd(rootPathsToHFAData{databasePath}); % Move from the server to the database
        over_count = over_count + 1;          % Increase the position in the file list and repeat the loop
    end
end