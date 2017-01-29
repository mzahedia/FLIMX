classdef FLIMXFitResultImport < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
        % read
        files_asc = {};
        files_images = {};
        folderpath = '';
        maxCh = [];
        curName = '';
        curFile = '';
        % Roi
        axesMgr = [];
        measurementObj = [];
        buttonDown = false; %flags if mouse button is pressed
        finalROIVec = [];
        isDirty = false(1,5); %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
    end
    
    properties (Dependent = true)
        roiMode = 1;
        selectedCh = 1;
        currentROIVec = [];
        editFieldROIVec = [];
        myMeasurement = [];
    end
    
    methods
        %% dependent properties
        
        function out = get.myMeasurement(this)
            %get measurement or subject object
            out = this.measurementObj;
            if(isempty(out))
                out = this.FLIMXObj.curSubject.myMeasurement;
            end
        end
        function out = get.selectedCh(this)
            %get current selected channel
            if(~this.isOpenVisWnd())
                return
            end
            out = get(this.visHandles.popupChannel,'Value');
        end
        
        function set.selectedCh(this,val)
            if(~this.isOpenVisWnd())% || ~ischar(val))
                return
            end
            val(val>this.maxCh)=this.maxCh;
            set(this.visHandles.popupChannel,'Value',val);
            set(this.visHandles.tableASC,'Data',this.files_asc{val});
            val(val>size(this.files_images,2))=size(this.files_images,2);
            set(this.visHandles.tableImages,'Data',this.files_images{val});
        end
        
        function out = get.roiMode(this)
            %return number of selected roi mode (1: whole dataset, 2: auto, 3: custom)
            if(get(this.visHandles.radioAuto,'Value'))
                out = 2;
            elseif(get(this.visHandles.radioCustom,'Value'))
                out = 3;
            else
                out = 1;
            end
        end
        
        function set.roiMode(this,val)
            %set number of selected roi mode (1: whole dataset, 2: auto, 3: custom)
            switch val
                case 2
                    set(this.visHandles.radioDefault,'Value',0);
                    set(this.visHandles.radioAuto,'Value',1);
                    set(this.visHandles.radioCustom,'Value',0);
                    flag = 'off';
                case 3
                    set(this.visHandles.radioDefault,'Value',0);
                    set(this.visHandles.radioAuto,'Value',0);
                    set(this.visHandles.radioCustom,'Value',1);
                    flag = 'on';
                otherwise
                    set(this.visHandles.radioDefault,'Value',1);
                    set(this.visHandles.radioAuto,'Value',0);
                    set(this.visHandles.radioCustom,'Value',0);
                    flag = 'off';
            end
            set(this.visHandles.textXL,'Enable',flag);
            set(this.visHandles.textXH,'Enable',flag);
            set(this.visHandles.textYL,'Enable',flag);
            set(this.visHandles.textYH,'Enable',flag);
        end
        
        function out = get.editFieldROIVec(this)
            %make roi vector from
            x = this.myMeasurement.getRawXSz();
            y = this.myMeasurement.getRawYSz();
            cXl = max(1,str2double(get(this.visHandles.textXL,'String')));
            cXu = min(x,str2double(get(this.visHandles.textXH,'String')));
            cXl = max(1,min(cXl,cXu-1));
            cXu = min(x,max(cXu,cXl+1));
            cYl = max(1,str2double(get(this.visHandles.textYL,'String')));
            cYu = min(y,str2double(get(this.visHandles.textYH,'String')));
            cYl = max(1,min(cYl,cYu-1));
            cYu = min(y,max(cYu,cYl+1));
            out = [cXl, cXu, cYl, cYu];
            %             out = [str2double(get(this.visHandles.textXL,'String')) str2double(get(this.visHandles.textXH,'String')), ...
            %             str2double(get(this.visHandles.textYL,'String')), str2double(get(this.visHandles.textYH,'String'))];
        end
        
        function set.editFieldROIVec(this,val)
            %set roi points in GUI from roi vec (apply limits)
            if(length(val) == 4)
                set(this.visHandles.textXL,'String',max(1,val(1)))
                set(this.visHandles.textXH,'String',min(this.myMeasurement.getRawXSz(),val(2)));
                set(this.visHandles.textYL,'String', max(1,val(3)))
                set(this.visHandles.textYH,'String',min(this.myMeasurement.getRawYSz(),val(4)));
            end
        end
        
        function out = get.currentROIVec(this)
            %make ROI vector based on current GUI settings
            switch this.roiMode
                case 1
                    out = [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()];
                case 2
                    out = importWizard.getAutoROI(this.myMeasurement.getRawDataFlat(this.selectedCh),2);
                case 3
                    out = this.editFieldROIVec;
            end
        end
        %% Rest
        function this = FLIMXFitResultImport(hFLIMX)
            this.FLIMXObj = hFLIMX;
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.FLIMXFitResultImportFigure) || ~strcmp(get(this.visHandles.FLIMXFitResultImportFigure,'Tag'),'FLIMXFitResultImportFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI();
            figure(this.visHandles.FLIMXFitResultImportFigure);
        end
        
        function setupGUI(this)
        end
        function updateGUI(this)
            % check ob asc oder image wenn image, dann imread
            cfile = this.curFile;
            switch cfile
                case 'asc'
                    image = dlmread(fullfile(this.folderpath,this.curName{1}));
                case 'bmp'
                    image = imread(fullfile(this.folderpath,this.curName{1}));
            end
            
            axes(this.visHandles.axesROI);
            imshow(image);
            set(this.visHandles.editPath,'String',this.folderpath,'Enable','off');
        end
        
        
        %% Ask User
        function getfilesfromfolder(this)
            pathname = uigetdir('', 'Choose folder');
            if pathname == 0
                return
            end;
            files = dir(pathname);
            if size(files,1) == 0
                return
            end;
            % call folder selection
            % for each file extension
            names_asc = {};
            names_bmp = {};
            names_tif = {};
            maxChan = 16;
            column_asc = zeros(maxChan,1);
            column_bmp = zeros(maxChan,1);
            column_tif = zeros(maxChan,1);
            i = 1;
            stem = {};
            while(i <= length(files))
                [~,filename,ext] = fileparts(files(i).name);
                if(strcmp(ext,'.asc'))
                    idx_= strfind(filename,'_');
                    idxminus = strfind(filename,'-');
                    % Check: 2*'-' and '-_'
                    if length(strfind(filename,'-'))<2 || idx_(end)~=1+idxminus(end)
                        return % invalid filename
                    end;
                    stem{length(stem)+1} = (filename(1:idxminus(end-1)-1));
                end;
                i = i+1;
            end;
            % find most available word stem
            singlestem = unique(stem);
            counter = zeros(length(singlestem));
            for i=1:length(singlestem)
                for j=1:length(stem)
                    if strcmp(singlestem(i),stem(j))
                        counter(i)=counter(i)+1;
                    end;
                end;
            end;
            [~,place] = max(counter);
            subjectstamm = singlestem{place(1)};
            % delete other word stems
            files = files(strncmp({files.name},subjectstamm,length(subjectstamm)));
            % sort every file
            for i=1:length(files)
                if files(i).isdir == false
                    fullfilename = files(i).name;
                    [~,filename,ext] = fileparts(fullfilename);
                    aktstamm = filename(1:length(subjectstamm));
                    if aktstamm == subjectstamm
                        switch ext
                            case {'.asc', '.bmp', '.tif'}
                                % two digits
                                ChanNr = str2double(filename(length(subjectstamm)+4:length(subjectstamm)+5));
                                if isempty(ChanNr) || isnan(ChanNr)
                                    % one digit
                                    ChanNr = str2double(filename(length(subjectstamm)+4:length(subjectstamm)+4));
                                    if isempty(ChanNr) || isnan(ChanNr)
                                        return
                                    end;
                                end;
                                switch ext
                                    case '.asc'
                                        column_asc(ChanNr)=column_asc(ChanNr)+1;
                                        names_asc{column_asc(ChanNr),ChanNr}=filename;
                                    case '.bmp'
                                        column_bmp(ChanNr)=column_bmp(ChanNr)+1;
                                        names_bmp{column_bmp(ChanNr),ChanNr}=filename;
                                    otherwise % '.tif'
                                        column_tif(ChanNr)=column_tif(ChanNr)+1;
                                        names_tif{column_tif(ChanNr),ChanNr}=filename;
                                end;
                            otherwise
                        end;
                    end;
                end;
            end;
            path = pathname;
            this.folderpath = path;
            % FLIMXFitResultImport.files_asc = names_asc;
            [~,dim] = size(names_asc);
            this.maxCh = dim;
            filterindex = 1;
            lastPath = path;
            idx = strfind(lastPath,filesep);
            if(length(idx) > 1)
                lastPath = lastPath(1:idx(end-1));
            end
            for i=1:dim
                files = names_asc(:,i);
                files = files(~cellfun(@isempty,names_asc(:,i)));
                opt.ch = i;
                for i2=1:length(files)
                    files{i2} = strcat(files{i2}, '.asc');
                end;
                
                this.files_asc{i} = files;
            end;
            
            a = 2;
            % Set table bmp
            [~,dim] = size(names_bmp);
            filterindex = 1;
            lastPath = path;
            idx = strfind(lastPath,filesep);
            if(length(idx) > 1)
                lastPath = lastPath(1:idx(end-1));
            end
            clear files
            for i=1:dim
                files = names_bmp(:,i);
                files = files(~cellfun(@isempty,names_bmp(:,i)));
                opt.ch = i;
                for i2=1:length(files)
                    files{i2} = strcat(files{i2}, '.bmp');
                end;
                this.files_images{i} = files;
            end;
            
            %  this.dynParams.lastPath = lastPath;
            
        end
        
        
        
        function importall(this)
            
        end
        
        %colorbar
        function updateColorbar(this)
            %update the colorbar to the current color map
            temp = zeros(length(this.FLIMXObj.FLIMVisGUI.dynParams.cm),2,3);
            if(strcmp(this.FLIMXObj.FLIMVisGUI.getFLIMItem('l'),'Intensity'))
                temp(:,1,:) = gray(size(temp,1));
            else
                temp(:,1,:) = this.FLIMXObj.FLIMVisGUI.dynParams.cm;
            end
            if(strcmp(this.FLIMXObj.FLIMVisGUI.getFLIMItem('r'),'Intensity'))
                temp(:,2,:) = gray(size(temp,1));
            else
                temp(:,2,:) = this.FLIMXObj.FLIMVisGUI.dynParams.cm;
            end
            image(temp,'Parent',this.visHandles.cm_axes);
            ytick = (0:0.25:1).*size(this.FLIMXObj.FLIMVisGUI.dynParams.cm,1);
            ytick(1) = 1;
            set(this.visHandles.cm_axes,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
            ylim(this.visHandles.cm_axes,[1 size(this.FLIMXObj.FLIMVisGUI.dynParams.cm,1)]);
            %??????  setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.cm_axes,false);
        end
    end
    
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = FLIMXFitResultImportFigure();
            figure(this.visHandles.FLIMXFitResultImportFigure);
            % get user information
            this.getfilesfromfolder();
            %set callbacks
            string_list = {};
            for i=1:this.maxCh
                string_list{i}=num2str(i);
            end
            % popup
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel.','String',string_list);
            % table
            set(this.visHandles.tableASC,'CellSelectionCallback',@this.GUI_tableASC_CellSelectionCallback);
            set(this.visHandles.tableImages,'CellSelectionCallback',@this.GUI_tableImages_CellSelectionCallback);
            set(this.visHandles.tableSelected,'CellSelectionCallback',@this.GUI_tableSelected_CellSelectionCallback);
            %   set(this.visHandles.pushDraw,'Callback',@this.GUI_pushDraw_Callback,'TooltipString','Draw selected ASC.');
            % radiobutton
            set(this.visHandles.radioDefault,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioAuto,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioCustom,'Callback',@this.GUI_radioROI_Callback);
            % push button
            set(this.visHandles.pushSelection,'Callback',@this.GUI_pushSelection_Callback,'TooltipString','Select files.');
            set(this.visHandles.pushBrowse,'Callback',@this.GUI_pushBrowse_Callback,'TooltipString','Browse folder.');
            % edit fields
            set(this.visHandles.textXL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textXH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYH,'Callback',@this.GUI_editROI_Callback);
            % mouse
            set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonDownFcn',@this.GUI_mouseButtonDown_Callback);
            set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
            set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            % initialisierung
            set(this.visHandles.popupStudy,'String',this.FLIMXObj.curSubject.myParent.name);
            set(this.visHandles.popupSubject,'String',this.FLIMXObj.curSubject.name);
            set(this.visHandles.editPath,'String',this.folderpath,'Enable','off');
            
            this.selectedCh = 1;
            this.updateColorbar();
            % creaete axes obj
            cm = this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity;
            if(isempty(cm))
                cm = gray(256);
            end
            this.axesMgr = axesWithROI(this.visHandles.axesROI,this.visHandles.axesCb,this.visHandles.textCbBottom,this.visHandles.textCbTop,this.visHandles.editCP,cm);
            a = 2;
        end
        
        function updateROIControls(this,roi)
            %apply limits to roi points and update roi display in GUI
            if(isempty(roi))
                roi = this.editFieldROIVec;
            end
            if(roi(4) <= this.myMeasurement.getRawYSz() && roi(2) <= this.myMeasurement.getRawXSz())
                data = this.myMeasurement.getRawDataFlat(this.selectedCh);
                if(~isempty(data))
                    data = data(roi(3):roi(4),roi(1):roi(2));
                end
            else
                data = [];
            end
            total = sum(data(:));
            set(this.visHandles.editTotalPh,'String',sprintf('%.2f million',total/1000000));
            set(this.visHandles.editAvgPh,'String',num2str(total/numel(data),'%.2f'));
            %this.FLIMXObj.FLIMFitGUI.plotRawDataROI(this.visHandles.axesROI,
            this.axesMgr.drawROIBox(roi);
            set(this.visHandles.textXWidth,'String',num2str(1+abs(roi(1)-roi(2))));
            set(this.visHandles.textYWidth,'String',num2str(1+abs(roi(3)-roi(4))));
        end
        %% GUI Callbacks
        % Tables
        function GUI_tableASC_CellSelectionCallback(this,hObject,eventdata)
            if isempty(eventdata.Indices)
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            Data=get(this.visHandles.tableASC, 'Data');
            file=Data(row,1);
            this.curName = file;
            this.curFile = 'asc';
            this.updateGUI();
        end
        
        function GUI_tableSelected_CellSelectionCallback(this,hObject,eventdata)
            if isempty(eventdata.Indices)
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            Data=get(this.visHandles.tableSelected, 'Data');
            file=Data(row,1);
            this.curName = file;
            this.curFile = Data{row,2};
            this.updateGUI();
        end
        
        function GUI_tableImages_CellSelectionCallback(this,hObject, eventdata)
            if isempty(eventdata.Indices)
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            Data=get(this.visHandles.tableImages, 'Data');
            file=Data(row,1);
            this.curName = file;
            this.curFile = 'bmp';
            this.updateGUI();
        end
        
        % Popup
        function GUI_popupChannel_Callback(this,hObject, eventdata)
            this.selectedCh=get(this.visHandles.popupChannel,'Value');
        end
        
        % Pushbutton
        function GUI_pushDraw_Callback(this,hObject, eventdata)
            
        end
        function GUI_pushBrowse_Callback(this,hObject, eventdata)
            this.getfilesfromfolder();
        end
        function GUI_pushSelection_Callback(this,hObject, eventdata)
            file = get(this.visHandles.tableSelected,'Data');
            f1 = file(:,1);
            f2 = file(:,2);
            f3 = file(:,3);
            f1 = f1(~cellfun(@isempty,f1));
            f2 = f2(~cellfun(@isempty,f2));
            f3 = f3(~cellfun(@isempty,f3));
            
            file = [f1, f2, f3 ];
            if isempty(find(ismember(f1,this.curName{1})))
                file(end+1,1:3) = [this.curName, this.curFile, this.selectedCh];
            else
                msgbox('File is already selected.', 'Already selected');
            end
            set(this.visHandles.tableSelected,'Data',file);
            
        end
        
        %radio button
        function GUI_radioROI_Callback(this,hObject, eventdata)
            %
            switch get(hObject,'Tag')
                case 'radioAuto'
                    this.roiMode = 2;
                case 'radioCustom'
                    this.roiMode = 3;
                otherwise
                    %should not happen, we assume default = whole dataset
                    this.roiMode = 1;
            end
            this.isDirty(4) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.isDirty(1) = true;
            roi = this.currentROIVec;
            this.editFieldROIVec = roi;
            this.finalROIVec = roi;
            this.updateGUI();
        end
        function GUI_editROI_Callback(this,hObject, eventdata)
            %
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.finalROIVec = this.editFieldROIVec;
            this.updateROIControls([]);
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %mouse callbacks
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function GUI_mouseButtonDown_Callback(this, hObject, eventdata)
            %executes on click in window
            if(this.roiMode ~= 3)
                return;
            end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            set(this.visHandles.textXL,'String',round(abs(cp(1))));
            set(this.visHandles.textYL,'String',round(abs(cp(2))));
            this.buttonDown = true;
        end
        
        function GUI_mouseMotion_Callback(this, hObject, eventdata)
            %executes on mouse move in window
            %             if(this.roiMode ~= 3)
            %                 return;
            %             end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','arrow');
                this.editFieldROIVec = this.finalROIVec;
                this.updateROIControls([]);
                return;
            end
            cp=fix(cp+0.52);
            if(cp(1) >= 1 && cp(1) <= this.myMeasurement.getRawYSz() && cp(2) >= 1 && cp(2) <= this.myMeasurement.getRawXSz())
                %inside axes
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','cross');
                if(this.buttonDown)
                    set(this.visHandles.textXH,'String',round(abs(cp(1))));
                    set(this.visHandles.textYH,'String',round(abs(cp(2))));
                    roi = [str2double(get(this.visHandles.textXL,'String')), cp(1),...
                        str2double(get(this.visHandles.textYL,'String')), cp(2)];
                    this.updateROIControls(roi);
                else
                    set(this.visHandles.textXL,'String',round(abs(cp(1))));
                    set(this.visHandles.textYL,'String',round(abs(cp(2))));
                end
                %update current point field
                raw = this.myMeasurement.getRawDataFlat(this.selectedCh);
                if(~isempty(raw))
                    set(this.visHandles.editCP,'String',num2str(raw(cp(2),cp(1))));
                end
            else
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','arrow');
                this.editFieldROIVec = this.finalROIVec;
                this.updateROIControls([]);
            end
        end
        
        function GUI_mouseButtonUp_Callback(this, hObject, eventdata)
            %executes on click in window
            if(this.roiMode ~= 3)
                return;
            end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            this.buttonDown = false;
            cXl = str2double(get(this.visHandles.textXL,'String'));
            cXu = round(abs(cp(1)));
            cYl = str2double(get(this.visHandles.textYL,'String'));
            cYu = round(abs(cp(2)));
            this.editFieldROIVec = [min(cXl,cXu), max(cXl,cXu), min(cYl,cYu), max(cYl,cYu)];
            this.finalROIVec = this.editFieldROIVec;
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.updateROIControls([]);
        end
    end
    methods(Static)
        function roi = getAutoROI(imgFlat,roiBinning)
            %try to determine a reasonable ROI
            if(isempty(imgFlat))
                roi = [];
                return
            end
            th = sum(imgFlat(:) / numel(imgFlat));
            bin = imgFlat >= th*0.5; %fitParams.roi_autoThreshold;
            bin =  imerode(bin,strel('square', max(1,roiBinning)));
            xl = find(any(bin,1),1,'first');
            xh = find(any(bin,1),1,'last');
            yl = find(any(bin,2),1,'first');
            yh = find(any(bin,2),1,'last');
            bin = bin(yl:yh,xl:xh);
            %finetune a bit
            rows = sum(bin,2) > size(bin,1)/10;
            cols = sum(bin,1) > size(bin,2)/10;
            xl_old = xl;
            yl_old = yl;
            xl = xl_old-1+find(cols,1,'first');
            xh = xl_old-1+find(cols,1,'last');
            yl = yl_old-1+find(rows,1,'first');
            yh = yl_old-1+find(rows,1,'last');
            roi = [xl xh yl yh];
        end
    end
end

