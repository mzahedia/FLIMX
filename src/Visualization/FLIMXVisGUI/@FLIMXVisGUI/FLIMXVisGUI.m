classdef FLIMXVisGUI < handle
    %=============================================================================================================
    %
    % @file     FLIMXVisGUI.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     July, 2015
    %
    % @section  LICENSE
    %
    % Copyright (C) 2015, Matthias Klemm. All rights reserved.
    %
    % Redistribution and use in source and binary forms, with or without modification, are permitted provided that
    % the following conditions are met:
    %     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
    %       following disclaimer.
    %     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
    %       the following disclaimer in the documentation and/or other materials provided with the distribution.
    %     * Neither the name of FLIMX authors nor the names of its contributors may be used
    %       to endorse or promote products derived from this software without specific prior written permission.
    %
    % THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
    % WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
    % PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    % INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    % PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    % HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    % NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    % POSSIBILITY OF SUCH DAMAGE.
    %
    %
    % @brief    A class to represent a GUI, which visualizes FLIM parameter, enables statistics computations, ...
    %
    properties(GetAccess = public, SetAccess = protected)
        dynParams = []; %sores dynamic display parameters, e.g. color maps
        visHandles = []; %structure to save handles to uicontrols
        objHandles = []; %handles runtime objects except for fdt
        FLIMXObj = []; %FLIMXObj object        
        myStatsDescr = [];
        myStatsGroupComp = [];
        myStatsMVGroup = [];
    end
    properties(GetAccess = public, SetAccess = private)
        stopFlag = false;
    end
    properties (Dependent = true)
        fdt = []; %FDTree object
        visParams = []; %options for visualization
        statParams = []; %options for statistics
        exportParams = []; %options for export
        filtParams = []; %options for filtering        
        generalParams = []; %general parameters        
    end

    methods
        function this = FLIMXVisGUI(flimX)
            %Constructs a FLIMXVisGUI object.
            if(isempty(flimX))               
                error('Handle to FLIMX object required!');
            end
            this.FLIMXObj = flimX;
            this.myStatsDescr = StatsDescriptive(this);
            this.myStatsGroupComp = StatsGroupComparison(this);
            this.myStatsMVGroup = StatsMVGroupMgr(this);
            this.dynParams.lastPath = flimX.getWorkingDir();
            this.makeDynParams();
%             try
%                 this.dynParams.cm = eval(sprintf('%s(256)',lower(this.generalParams.cmType)));
%             catch
%                 this.dynParams.cm = jet(256);
%             end
%             if(this.generalParams.cmInvert)
%                 this.dynParams.cm = flipud(this.dynParams.cm);
%             end
%             try
%                 this.dynParams.cmIntensity = eval(sprintf('%s(256)',lower(this.generalParams.cmIntensityType)));
%             catch
%                 this.dynParams.cmIntensity = gray(256);
%             end
%             if(this.generalParams.cmIntensityInvert)
%                 this.dynParams.cmIntensity = flipud(this.dynParams.cmIntensity);
%             end
            this.dynParams.mouseButtonDown = false;
            %this.dynParams.mouseButtonUp = false;
            this.dynParams.mouseButtonDownROI = [];
            this.dynParams.mouseButtonIsLeft = false;
            this.dynParams.mouseButtonIsInsideROI = false;
            this.dynParams.lastExportFile = 'image.png';
            %init objects
            this.fdt.setShortProgressCallback(@this.updateShortProgress);
            this.fdt.setLongProgressCallback(@this.updateLongProgress);
        end %constructor
        
        %% input functions        
        function setStudy(this,s,val)
            % set current study of side s
            if(isempty(s))
                s = ['l' 'r'];
            end
            allStudies = this.visHandles.study_l_pop.String;
            if(ischar(val))
                val = find(strcmp(val,allStudies),1);            
            elseif(isnumeric(val))
                val = max(1,min(val,length(allStudies)));
            end
            if(isempty(val))
                return
            end
            for i = 1:length(s)
                this.visHandles.(sprintf('study_%s_pop',s(i))).Value = val;
            end
            this.setupGUI();
            this.updateGUI([]);
        end
        
        function success = setSubject(this,s,val)
            % set current subject of side s
            success = true;
            if(isempty(s))
                success = false;
                return
            end
            allSubjects = this.visHandles.(sprintf('subject_%s_pop',s)).String;
            if(ischar(val))
                val = find(strcmp(val,allSubjects),1);            
            elseif(isnumeric(val))
                val = max(1,min(val,length(allSubjects)));
            end
            if(isempty(val))
                success = false;
                return
            end
            this.visHandles.(sprintf('subject_%s_pop',s)).Value = val;
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.FLIMXVisGUIFigure) || ~strcmp(get(this.visHandles.FLIMXVisGUIFigure,'Tag'),'FLIMXVisGUIFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupPopUps([]);
            this.setupGUI();
            this.updateGUI([]);
            figure(this.visHandles.FLIMXVisGUIFigure);
        end %checkVisWnd
                
        function clearAxes(this,s)            
            %clear axes
            if(isempty(s))
                this.clearAxes('l');
                this.clearAxes('r');
                return
            end
            cla(this.visHandles.(sprintf('main_%s_axes',s)));
            axis(this.visHandles.(sprintf('main_%s_axes',s)),'off');
            cla(this.visHandles.(sprintf('supp_%s_axes',s)));
            axis(this.visHandles.(sprintf('supp_%s_axes',s)),'off');
            cla(this.visHandles.cm_l_axes);
            cla(this.visHandles.cm_r_axes);
            axis(this.visHandles.cm_l_axes,'off');
            axis(this.visHandles.cm_r_axes,'off');
            this.setupPopUps(s);
        end
        
        function setupPopUps(this,s)
            %set defaults
            if(isempty(s))
                s = ['l' 'r'];
            end
            for i=1:length(s)
                set(this.visHandles.(sprintf('channel_%s_pop',s(i))),'Value',1,'Visible','on');
                set(this.visHandles.(sprintf('flim_param_%s_pop',s(i))),'Value',1,'Visible','on');
                set(this.visHandles.(sprintf('dimension_%s_pop',s(i))),'Enable','on');
                set(this.visHandles.(sprintf('var_mode_%s_pop',s(i))),'Value',1,'Enable','off');
                set(this.visHandles.(sprintf('scale_%s_pop',s(i))),'Value',1);
            end
        end
        
        function setupGUI(this)
            %setup GUI (popup menus, enable/disable/show/hide controls)
            if(~this.isOpenVisWnd())
                return
            end
            side =  ['l' 'r'];
            studies = this.fdt.getAllStudyNames();
            this.makeDynParams();
            %colormap(this.visHandles.cm_axes,this.dynParams.cm);
            for j = 1:length(side)
                s = side(j);
                curStudy = this.getStudy(s); %current study name and index
                curStudyIdx = find(strcmp(curStudy,studies),1);
                if(isempty(curStudyIdx) || curStudyIdx ~= get(this.visHandles.(sprintf('study_%s_pop',s)),'Value'))
                    set(this.visHandles.(sprintf('study_%s_pop',s)),'Value',min(get(this.visHandles.(sprintf('study_%s_pop',s)),'Value'),length(studies)),'String',studies);
                else
                    set(this.visHandles.(sprintf('study_%s_pop',s)),'String',studies,'Value',curStudyIdx);
                end
                curStudy = this.getStudy(s);
                %update conditions
                conditions = this.fdt.getStudyConditionsStr(this.getStudy(s));
                set(this.visHandles.(sprintf('view_%s_pop',s)),'String',conditions,'Value',min(get(this.visHandles.(sprintf('view_%s_pop',s)),'Value'),length(conditions)));
                curCondition = this.getCondition(s);          %current condition name
                nrSubs = this.fdt.getNrSubjects(curStudy,curCondition);    %Number of subjects
                if(~nrSubs)
                    this.clearAxes(s);
                    this.objHandles.(sprintf('%sdo',s)).updateColorbar();                                                    
                    %clear display objects
                    this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
                    %channel popups
                    set(this.visHandles.(sprintf('channel_%s_pop',s)),'String','Ch','Value',1);                    
                    %setup main popup menus
                    set(this.visHandles.(sprintf('flim_param_%s_pop',s)),'String','params','Value',1);
                    %setup study controls                    
                    set(this.visHandles.(sprintf('subject_%s_pop',s)),'String','dataset','Value',1);                    
                    %update crossSections
                    this.objHandles.crossSectionx.updateCtrls();
                    this.objHandles.crossSectiony.updateCtrls();
                    %ROI
                    this.objHandles.(sprintf('%sROI',s)).setupGUI();
                    this.objHandles.(sprintf('%sZScale',s)).setupGUI();
                    %descriptive statistics
                    this.objHandles.(sprintf('%sdo',s)).makeDSTable();
                    %arithmetic images
                    this.objHandles.AI.updateCtrls();
                    continue
                end
                %update subject selection popups
                allSubStr = this.fdt.getAllSubjectNames(curStudy,curCondition);
                if(~isempty(allSubStr))
                    curSubject = this.getSubject(s);
                    curSubjectIdx = find(strcmp(curSubject,allSubStr),1);
                    if(isempty(curSubjectIdx))
                        set(this.visHandles.(sprintf('subject_%s_pop',s)),'String',allSubStr,'Value',min(get(this.visHandles.(sprintf('subject_%s_pop',s)),'Value'),nrSubs));
                    else
                        set(this.visHandles.(sprintf('subject_%s_pop',s)),'String',allSubStr,'Value',curSubjectIdx);
                    end
                else
                    set(this.visHandles.(sprintf('subject_%s_pop',s)),'String','dataset','Value',1);
                end
                this.myStatsGroupComp.setupGUI();
                curSubject = this.getSubject(s);
                [chStr, chNrs] = this.fdt.getChStr(curStudy,curSubject);
                if(~isempty(chStr))
                    %channel popups
                    oldCh = this.getChannel(s);
                    chPos = find(chNrs == oldCh,1);
                    if(isempty(chPos))
                        set(this.visHandles.(sprintf('channel_%s_pop',s)),'String',chStr,'Value',...
                            min(length(chStr),get(this.visHandles.(sprintf('channel_%s_pop',s)),'Value')));
                    else
                        set(this.visHandles.(sprintf('channel_%s_pop',s)),'String',chStr,'Value',chPos);                        
                    end
                    %setup main popup menus
                    chObj = this.fdt.getChObjStr(curStudy,curSubject,this.getChannel(s));
                    if(~isempty(chObj))
                        MVGroupNames = this.fdt.getMVGroupNames(curStudy,1);
                        idx = strncmp('MVGroup_',MVGroupNames,8);
                        if(~isempty(idx))
                            MVGroupNames = MVGroupNames(idx);
                        end
                    else
                        MVGroupNames = [];
                    end
                    %determine if variation selection can be activated
                    if(~isempty(MVGroupNames))
                        set(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Enable','On');
                    else
                        set(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Enable','Off');
                        set(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Value',1);
                    end
                    %setup gui according to variation selection
                    switch get(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Value')
                        case 1 %univariate
                            %add cluster objects to channel object string
                            %chObj = unique([chObj;MVGroupNames]);
                            set(this.visHandles.(sprintf('subject_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('subject_%s_dec_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('subject_%s_inc_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dimension_%s_pop',s)),'Enable','on');
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 2 %multivariate
                            chObj = MVGroupNames;
                            set(this.visHandles.(sprintf('subject_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('subject_%s_dec_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('subject_%s_inc_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dimension_%s_pop',s)),'Enable','off','Value',3);
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 3 %condition clusters
                            %show only clusters
                            chObj = MVGroupNames;
                            set(this.visHandles.(sprintf('subject_%s_pop',s)),'Visible','off');
                            set(this.visHandles.(sprintf('subject_%s_dec_button',s)),'Visible','off');
                            set(this.visHandles.(sprintf('subject_%s_inc_button',s)),'Visible','off');
                            set(this.visHandles.(sprintf('dimension_%s_pop',s)),'Enable','on');
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 4 %global clusters
                            globalMVGroupNames = this.fdt.getGlobalMVGroupNames();
                            idx = strncmp('MVGroup_',globalMVGroupNames,8);
                            if(~isempty(idx))
                                globalMVGroupNames = globalMVGroupNames(idx);
                            end
                            if(isempty(globalMVGroupNames))
                                %global cluster not created yet
                                errordlg('No multivariate group in mulitple studies available! Please define in Statistics -> Multivariate Groups.','Error Multivariate Groups');
                                set(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Value',1);
                                chObj = unique([chObj;MVGroupNames]);
                                set(this.visHandles.(sprintf('subject_%s_pop',s)),'Visible','on');
                                set(this.visHandles.(sprintf('subject_%s_dec_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('subject_%s_inc_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('dimension_%s_pop',s)),'Enable','on');
                                set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                                set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                            else
                                chObj = globalMVGroupNames;
                                set(this.visHandles.(sprintf('subject_%s_pop',s)),'Visible','off');
                                set(this.visHandles.(sprintf('subject_%s_dec_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('subject_%s_inc_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','off');
                                set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','off');
                            end
                    end
                    %supplementary plot histogram selection
                    if(get(this.visHandles.(sprintf('supp_axes_%s_pop',s)),'Value') == 2)
                        %Histogram
                        if(get(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Value') == 1)
                            %univariate
                            set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','on','Enable','on');
                        else %multivariate, clusters
                            set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','on','Enable','off','Value',1);
                        end
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Visible','on');
                        set(this.visHandles.(sprintf('color_scale_%s_panel',s)),'Visible','on');
                    else %none, crossSections
                        set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','off');
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Visible','off');
                        set(this.visHandles.(sprintf('color_scale_%s_panel',s)),'Visible','off');
                    end
                    if(~isempty(chObj))
                        oldPStr = get(this.visHandles.(sprintf('flim_param_%s_pop',s)),'String');
                        if(iscell(oldPStr))
                            oldPStr = oldPStr(get(this.visHandles.(sprintf('flim_param_%s_pop',s)),'Value'));
                        end
                        %try to find oldPStr in new pstr
                        idx = find(strcmp(oldPStr,chObj),1);
                        if(isempty(idx))
                            idx = min(get(this.visHandles.(sprintf('flim_param_%s_pop',s)),'Value'),length(chObj));
                        end            
                        set(this.visHandles.(sprintf('flim_param_%s_pop',s)),'String',chObj,'Value',idx);
                    else
                        %empty channels
                        set(this.visHandles.(sprintf('flim_param_%s_pop',s)),'String','params','Value',1);
                    end
                else
                    %no channels
                    this.clearAxes(s);
                    %clear display objects
                    this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
                    %channel popups
                    set(this.visHandles.(sprintf('channel_%s_pop',s)),'String','Ch','Value',1);
                    %setup main popup menus
                    set(this.visHandles.(sprintf('flim_param_%s_pop',s)),'String','params','Value',1);
                end
                %set arbitrary initial color value for new study
                cColor = this.fdt.getConditionColor(curStudy,curCondition);
                if(isempty(cColor) || length(cColor) ~= 3)
                    newColor = FDTStudy.makeRndColor();
                    set(this.visHandles.(sprintf('study_color_%s_button',s)),'Backgroundcolor',newColor);
                    this.fdt.setConditionColor(curStudy,curCondition,newColor);
                else
                    set(this.visHandles.(sprintf('study_color_%s_button',s)),'Backgroundcolor',cColor);
                end
                %colorbar
                this.objHandles.(sprintf('%sdo',s)).updateColorbar();
            end
            %arithmetic images
            this.objHandles.AI.updateCtrls();
        end %setupGUI
        
        function updateGUI(this,side)
            %update GUI
            if(~this.isOpenVisWnd())
                return
            end
            if(isempty(side))
                side =  ['l' 'r'];
            end
            %this.fdt.setCancelFlag(false);
            for j = 1:length(side)                
                s = side(j);                
                if(~this.fdt.getNrSubjects(this.getStudy(s),this.getCondition(s)))
                    continue
                end
                %update display objects
                this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
                %roi
                this.objHandles.(sprintf('%sROI',s)).setupGUI();
                this.objHandles.(sprintf('%sROI',s)).updateGUI([]);
                this.objHandles.(sprintf('%sZScale',s)).updateGUI([]);
                this.objHandles.(sprintf('%sdo',s)).updatePlots();
                this.objHandles.(sprintf('%sdo',s)).myColorScaleObj.checkCallback(this.getROIDisplayMode(s) > 1);                
                if(strcmp(s,'l'))
                    %update crossSections
                    this.objHandles.crossSectionx.updateCtrls();
                    this.objHandles.crossSectiony.updateCtrls();
                end
                switch get(this.visHandles.(sprintf('supp_axes_%s_pop',s)),'Value')
                    case 1 %none
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','off');
                    case {2,3,4} %histograms
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','off');
                    case 5 %horizontal crossSection
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','on');
                    case 6 %vertical crossSection
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','on'); 
                end
                %enable / disable intensity overlay functions
                var = get(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Value');
                dType = this.getFLIMItem(s);                
                %check if a cluster object is selected
                clf = false;
                switch var
                    case 1
                        if(strncmp(dType,'MVGroup',7))
                            %we have a cluster object in univariate mode                            
                            clf = true;
                        end
                    case 3
                        %condition cluster
                        clf = true;
                end
                if(clf)
                    %disable intensity overlay functions
                    set(this.visHandles.(sprintf('IO_%s_check',s)),'Enable','Off');
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'Enable','Off');
                    set(this.visHandles.(sprintf('IO_%s_inc_button',s)),'Enable','Off');
                    set(this.visHandles.(sprintf('IO_%s_dec_button',s)),'Enable','Off');
                else
                    %enable intensity overlay functions
                    set(this.visHandles.(sprintf('IO_%s_check',s)),'Enable','On');
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'Enable','On');
                    set(this.visHandles.(sprintf('IO_%s_inc_button',s)),'Enable','On');
                    set(this.visHandles.(sprintf('IO_%s_dec_button',s)),'Enable','On');
                end
            end %for j=1:length(side)
        end %updateGUI
        
        function updateShortProgress(this,x,text)
            %update short progress bar; inputs: progress x: 0..1, text on progressbar
            if(this.isOpenVisWnd())
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patch_short_progress,'XData',xpatch,'Parent',this.visHandles.short_progress_axes)
                yl = ylim(this.visHandles.short_progress_axes);
                set(this.visHandles.text_short_progress,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.short_progress_axes);
                drawnow;
            end
        end
        
        function updateLongProgress(this,x,text)
            %update long progress bar; inputs: progress x: 0..1, text on progressbar
            if(this.isOpenVisWnd())
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patch_long_progress,'XData',xpatch,'Parent',this.visHandles.long_progress_axes)
                yl = ylim(this.visHandles.long_progress_axes);
                set(this.visHandles.text_long_progress,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.long_progress_axes);
                drawnow;
            end
        end          
        
%         %colorbar
%         function updateColorbar(this)
%             %update the colorbar to the current color map
%             temp = zeros(length(this.dynParams.cm),2,3);
%             if(strcmp(this.getFLIMItem('l'),'Intensity'))
%                 temp(:,1,:) = gray(size(temp,1));
%             else
%                 temp(:,1,:) = this.dynParams.cm;
%             end
%             if(strcmp(this.getFLIMItem('r'),'Intensity'))
%                 temp(:,2,:) = gray(size(temp,1));
%             else
%                 temp(:,2,:) = this.dynParams.cm;
%             end
%             image(temp,'Parent',this.visHandles.cm_axes);
%             ytick = (0:0.25:1).*size(this.dynParams.cm,1);
%             ytick(1) = 1;
%             set(this.visHandles.cm_axes,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
%             ylim(this.visHandles.cm_axes,[1 size(this.dynParams.cm,1)]);
%             setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.cm_axes,false);
%         end
                               
        %% menu functions                
        function menuExit_Callback(this,hObject,eventdata)
            %close window
            this.myStatsMVGroup.closeCallback();
            this.myStatsDescr.menuExit_Callback();
            this.myStatsGroupComp.menuExit_Callback();
            if(ishandle(this.visHandles.FLIMXVisGUIFigure))
                delete(this.visHandles.FLIMXVisGUIFigure);
            end
            this.FLIMXObj.destroy(false);
        end
        
        function menuFiltOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis filtering options
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.filtParams;
            opts.defaults = this.filtParams; %todo
            new = GUI_Filter_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('filtering',new.prefs);
                this.updateGUI([]);
            end  
        end
        function menuStatOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis statistics options
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.statParams;
            opts.defaults = this.statParams; %todo
            new = GUI_Statistics_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('statistics',new.prefs);
                this.fdt.clearAllCIs(''); %can be more efficient
                this.fdt.clearAllMVGroupIs();
                this.myStatsGroupComp.clearResults();
                this.updateGUI([]);
                %instead?!
            end 
        end
        function menuVisOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis visualization options
            defaults.flimvis = this.visParams;
            defaults.general = this.generalParams; %todo
            defaults.region_of_interest = this.FLIMXObj.paramMgr.getParamSection('region_of_interest');
            new = GUI_FLIMXVisGUIVisualizationOptions(defaults.flimvis,defaults.general,defaults.region_of_interest,defaults,this.FLIMXObj.fdt);
            if(~isempty(new))
                %save to disk
                if(new.isDirty(1) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('flimvis_gui',new.flimvis);
                end
                if(new.isDirty(2) == 1)                    
                    if(this.generalParams.flimParameterView ~= new.general.flimParameterView)
                        this.FLIMXObj.fdt.unloadAllChannels();                        
                    end
                    this.FLIMXObj.paramMgr.setParamSection('general',new.general);
                    this.FLIMXObj.FLIMFitGUI.setupGUI();
                    this.FLIMXObj.FLIMFitGUI.updateGUI(1);
%                     if(new.general.cmIntensityPercentileLB ~= defaults.general.cmIntensityPercentileLB || new.general.cmIntensityPercentileUB ~= defaults.general.cmIntensityPercentileUB ||...
%                         new.general.cmPercentileLB ~= defaults.general.cmPercentileLB || new.general.cmPercentileUB ~= defaults.general.cmPercentileUB)
%                         this.objHandles.ldo.myColorScaleObj.checkCallback();
%                         this.objHandles.rdo.myColorScaleObj.checkCallback();
%                     end
                end
                if(new.isDirty(3) == 1) 
                    this.FLIMXObj.paramMgr.setParamSection('region_of_interest',new.region_of_interest);
                    this.fdt.clearAllCIs(''); %can be more efficient
                    this.FLIMXObj.FLIMFitGUI.updateGUI(1);
                end
                this.setupGUI();
                this.updateGUI([]);
            end            
        end
        
        function menuExpOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis export options
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.exportParams;
            opts.defaults = this.exportParams; %todo
            new = GUI_Export_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('export',new.prefs);
            end  
        end
                
        function menuDescriptive_Callback(this,hObject,eventdata)
            %show descriptive statistics tool window
            this.myStatsDescr.checkVisWnd(); 
            this.myStatsDescr.setCurrentStudy(this.getStudy('l'),this.getCondition('l'));
        end
        
        function menuHolmWilcoxon_Callback(this,hObject,eventdata)
            %show holm wilcoxon statistics tool window
            this.myStatsGroupComp.checkVisWnd();            
        end
        
        function menuClustering_Callback(this,hObject,eventdata)
            %show clustering tool window
            this.myStatsMVGroup.checkVisWnd();
        end
        
        function menuOpenStudyMgr_Callback(this,hObject,eventdata)
            %show study manager window
            this.FLIMXObj.studyMgrGUI.checkVisWnd();
            this.FLIMXObj.studyMgrGUI.curStudyName = this.getStudy('l');
        end
        
        function menuOpenFLIMXFit_Callback(this,hObject,eventdata)
            %show FLIMXFit GUI window
            this.FLIMXObj.FLIMFitGUI.checkVisWnd();
        end        
        
        function menuExportFigure_Callback(this,hObject,eventdata)
            %export figure (therefore redraw selected axes in new figure)   
            tag = get(hObject,'Tag');
            side = 'l';            
            if(contains(tag,'R'))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(contains(tag,'B'))
                pType = 'supp'; %supp. plot
            end
            %[pathstr,name,ext] = fileparts(this.dynParams.lastExportFile);
            formats = {'*.png','Portable Network Graphics (*.png)';...
                '*.jpg','Joint Photographic Experts Group (*.jpg)';...
                '*.eps','Encapsulated Postscript (*.eps)';...
                '*.tiff','TaggedImage File Format (*.tiff)';...
                '*.bmp','Windows Bitmap (*.bmp)';...
                '*.emf','Windows Enhanced Metafile (*.emf)';...
                '*.pdf','Portable Document Format (*.pdf)';...
                '*.fig','MATLAB figure (*.fig)';...
                '*.png','16-bit Portable Network Graphics (*.png)';...
                '*.jpg','16-bit Joint Photographic Experts Group (*.jpg)';...
                '*.tiff','16-bit TaggedImage File Format (*.tiff)';...
                };
            [~, file] = fileparts(this.dynParams.lastExportFile);
            [file, path, filterindex] = uiputfile(formats,'Export Figure as',file);
            if ~path ; return ; end
            [~, file] = fileparts(file); %strip off extension incase user added something invalid
            ext = formats{filterindex,1}(2:end);
            fn = fullfile(path,[file,ext]);
            this.dynParams.lastExportFile = file;
            switch filterindex
                case 5 %'*.bmp'
                    str = '-dbmp';
                case 6% '*.emf'
                    str = '-dmeta';
                case 3 %'*.eps'
                    str = '-depsc2';
                case 2 %'*.jpg'
                    str = '-djpeg';
                case 7 %'*.pdf'
                    str = '-dpdf';
                case 1 %'*.png'
                    str = '-dpng';
                case 4 %'*.tiff'
                    str = '-dtiff';                    
            end
            ss = get(0,'screensize');
            hFig = figure('Position',ss - [0 0 250 75]);
            set(hFig,'Renderer','Painters');
            feObj = FLIMXFigureExport(this.objHandles.(sprintf('%sdo',side)));
            feObj.makeExportPlot(hFig,pType);
            %pause(1) %workaround for wrong painting
            switch filterindex
                case 5 %bmp
                    print(hFig,str,['-r' num2str(this.exportParams.dpi)],fn);
                case 8
                    savefig(hFig,fn);
                case {9,11}
                    imwrite(uint16(feObj.mainExportXls),fn);
                case 10
                    imwrite(uint16(feObj.mainExportXls),fn,'BitDepth',16,'Mode','lossless');
                otherwise
                    if(this.exportParams.resampleImage)
                        %resample image to desired resolution, add color bar, box, lines, ...
                        %print(hFig,str,['-r' num2str(this.exportParams.dpi)],fn);
                        exportgraphics(feObj.h_m_ax,fn,'Resolution',this.exportParams.dpi);
                    else
                        %export image in native resolution with color bar, box, lines, ...
                        imwrite(flipud(feObj.mainExportColors),fn);
                    end
            end
            if(ishandle(hFig))
                close(hFig);
            end
        end
        
        function menuExportAnimation_Callback(this,hObject,eventdata)
            %export a batch of figures or an animation from different subjects
            tag = get(hObject,'Tag');
            side = 'l';            
            if(contains(tag,'R'))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(contains(tag,'B'))
                pType = 'supp'; %supp. plot
            end
            this.stopFlag = false;
            [settings, button] = settingsdlg(...
                'Description','This tool will export the chosen figure for each subject in the currently selected view of the current study.',...
                'title' , 'Figure Batch Export',...
                'Export Batch of Figures or Animation',{'Batch of Figures';'Animation'},...
                'Use Subject Name as File Name',false,...
                'Add Text Overlay',true,...
                'Overlay Type',{'Running Number';'Subject Name'} );
            %check user inputs
            if(~strcmpi(button, 'ok'))
                %user pressed cancel or has entered rubbish -> abort
                return
            end
            ss = get(0,'screensize');
            nSubjects = length(this.visHandles.(sprintf('subject_%s_pop',side)).String);
            switch settings.ExportBatchOfFiguresOrAnimation
                case 'Batch of Figures'
                    formats = {'*.png','Portable Network Graphics (*.png)';...
                        '*.jpg','Joint Photographic Experts Group (*.jpg)';...
                        '*.eps','Encapsulated Postscript (*.eps)';...
                        '*.tiff','TaggedImage File Format (*.tiff)';...
                        %'*.bmp','Windows Bitmap (*.bmp)';...
                        '*.emf','Windows Enhanced Metafile (*.emf)';...
                        '*.pdf','Portable Document Format (*.pdf)';...
                        '*.fig','MATLAB figure (*.fig)';...
                        '*.png','16-bit Portable Network Graphics (*.png)';...
                        '*.jpg','16-bit Joint Photographic Experts Group (*.jpg)';...
                        '*.tiff','16-bit TaggedImage File Format (*.tiff)';...
                        };
                    [~, file] = fileparts(this.dynParams.lastExportFile);
                    [file, path, filterindex] = uiputfile(formats,'Export Figure as',file);
                    if ~path ; return ; end
                    [~, file] = fileparts(file); %strip off extension incase user added something invalid
                    ext = formats{filterindex,1}(2:end);
                    switch filterindex
%                         case 5 %'*.bmp'
%                             str = '-dbmp';
                        case 5% '*.emf'
                            str = '-dmeta';
                        case 3 %'*.eps'
                            str = '-depsc2';
                        case 2 %'*.jpg'
                            str = '-djpeg';
                        case 6 %'*.pdf'
                            str = '-dpdf';
                        case 1 %'*.png'
                            str = '-dpng';
                        case 4 %'*.tiff'
                            str = '-dtiff';
                    end
                case 'Animation'
                    [file, path] = uiputfile({'*.gif','Graphics Interchange Format (*.gif)'},'Export Animation as',this.dynParams.lastExportFile);
                    if ~path ; return ; end
            end            
            [~,file] = fileparts(file);
            hFig = figure('Position',ss - [0 0 250 75]);
            set(hFig,'Renderer','Painters');
            feObj = FLIMXFigureExport(this.objHandles.(sprintf('%sdo',side)));
            updateLongProgress(this,0.01,'0.0%% - ETA: -');
            tStart = clock;
            for i = 1:nSubjects
                if(this.stopFlag)
                    break
                end
                if(settings.UseSubjectNameAsFileName)
                    fn = fullfile(path,[file,'_',this.visHandles.(sprintf('subject_%s_pop',side)).String{i},ext]);
                else
                    fn = fullfile(path,sprintf('%s_%02.0f%s',file,i,ext));
                end
                this.visHandles.(sprintf('subject_%s_pop',side)).Value = i;
                this.updateGUI(side);  
                feObj.sethfdMain([]);
                %roi
%                 feObj.updatePlots();
%                 feObj.myColorScaleObj.checkCallback(this.getROIDisplayMode(s) > 1);  
                feObj.makeExportPlot(hFig,pType);
                pause(1) %workaround for wrong painting
                if(settings.AddTextOverlay)
                    switch settings.OverlayType
                        case 'Running Number'
                            feObj.addTextOverlay(num2str(i));
                        case 'Subject Name'
                            feObj.addTextOverlay(this.visHandles.(sprintf('subject_%s_pop',side)).String{i});
                    end
                end                
                switch settings.ExportBatchOfFiguresOrAnimation
                    case 'Batch of Figures'
                        switch filterindex
                            case 7
                                savefig(hFig,fn);
                            case {8,10} %16 bit png / tiff
                                %no color bar, box, lines, ...
                                imwrite(uint16(feObj.mainExportXls),fn);
                            case 9 %16 bit jpg
                                %no color bar, box, lines, ...
                                imwrite(uint16(feObj.mainExportXls),fn,'BitDepth',16,'Mode','lossless');
                            otherwise
                                if(this.exportParams.resampleImage || settings.AddTextOverlay)
                                    % fr = getframe(feObj.getHandleMainAxes());
                                    % imwrite(fr.cdata,fn);
                                    %resample image to desired resolution, add color bar, box, lines, ...
                                    %print(hFig,str,['-r' num2str(this.exportParams.dpi)],fn);
                                    exportgraphics(feObj.h_m_ax,fn,'Resolution',this.exportParams.dpi);
                                else
                                    %export image in native resolution without color bar, box, lines, ...
                                    imwrite(flipud(feObj.mainExportColors),fn);
                                end
                        end
                    case 'Animation'
                        fr = getframe(feObj.getHandleMainAxes());
                        [imind,cm] = rgb2ind(fr.cdata,256);
                        % Write to the GIF File
                        if(i == 1)
                            imwrite(imind,cm,fn,'gif','Loopcount',inf,'DelayTime',0.1); % 1s delay between frames
                        else
                            imwrite(imind,cm,fn,'gif','WriteMode','append');
                        end
                end
                %updateLongProgress(this,0,'');                
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(nSubjects-i)); %mean cputime for finished runs * cycles left
                minutes = minutes + hours * 60; %unlikely to take hours
                this.updateLongProgress(i/nSubjects,sprintf('%02.1f%% - ETA: %02.0fm %02.0fs',i/nSubjects*100,minutes,secs));                
            end
            close(hFig);
            [~,this.dynParams.lastExportFile] = fileparts(file);
            updateLongProgress(this,0,'');
        end
        
        function menuExportMovie_Callback(this,hObject,eventdata)
            %export a movie
            this.objHandles.movObj.checkVisWnd();
        end
        
        function menuAbout_Callback(this,hObject,eventdata)
            %
            GUI_versionInfo(this.FLIMXObj.paramMgr.getParamSection('about'),this.FLIMXObj.curSubject.aboutInfo());
        end
        
        function menuUserGuide_Callback(this,hObject,eventdata)
            %
            FLIMX.openFLIMXUserGuide();
        end
        
        function menuWebsite_Callback(this,hObject,eventdata)
            %
            FLIMX.openFLIMXWebSite();
        end
        
        
        %% dependent properties
        function out = get.fdt(this)
            %shortcut to fdt
            out = this.FLIMXObj.fdt;
        end
        
        function out = get.generalParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('general');
        end
        
        function out = get.visParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('flimvis_gui');
        end        
        
        function set.visParams(this,val)
            %
            this.FLIMXObj.paramMgr.setParamSection('flimvis_gui',val);
        end
        
        function out = get.statParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('statistics');
        end
        
        function out = get.exportParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('export');
        end
        
        function out = get.filtParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('filtering');
        end
        
        %% get current GUI values
        function out = getScale(this,s)
            %get current channel number of side s
            out = get(this.visHandles.(sprintf('scale_%s_pop',s)),'Value');
        end
        
        function [dType, dTypeNr] = getFLIMItem(this,s)
            %get datatype and number of currently selected FLIM item
            list = get(this.visHandles.(sprintf('flim_param_%s_pop',s)),'String');
            ma_pop_sel = get(this.visHandles.(sprintf('flim_param_%s_pop',s)),'Value');
            switch get(this.visHandles.(sprintf('var_mode_%s_pop',s)),'Value')                
                case {1,3,4} %univariate / condition cluster
                    [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(list(ma_pop_sel,:));
                case 2 %multivariate
                    cMVs = this.fdt.getStudyMVGroupTargets(this.getStudy(s),list{ma_pop_sel});
                    %get multivariate targets out of cluster targets
                    MVTargets = unique([cMVs.x,cMVs.y]);
                    dType = cell(length(MVTargets),1);
                    dTypeNr = zeros(length(MVTargets),1);
                    for i = 1:length(MVTargets)
                        [dType(i), dTypeNr(i)] = FLIMXVisGUI.FLIMItem2TypeAndID(MVTargets{i});
                    end                    
            end
        end
        
        function out = getChannel(this,s)
            %get current channel number of side s
            out = 1;
            str = get(this.visHandles.(sprintf('channel_%s_pop',s)),'String');
            str = str(get(this.visHandles.(sprintf('channel_%s_pop',s)),'Value'));
            idx = isstrprop(str, 'digit');
            if(~iscell(idx))
                return
            end
            idx = idx{:};
            str = char(str);
            out = str2double(str(idx));
        end
        
        function out = getROIDisplayMode(this,s)
            %get '2D', ROI 2D or ROI 3D
            out = get(this.visHandles.(sprintf('dimension_%s_pop',s)),'Value');
        end
        
        function out = getDType(this,s)
            %get current data type of side s
            out = '';
            str = this.visHandles.(sprintf('flim_param_%s_pop',s)).String;
            if(~ischar(str) && ~isempty(str))
                out = FLIMXVisGUI.FLIMItem2TypeAndID(str{this.visHandles.(sprintf('flim_param_%s_pop',s)).Value});
                out = out{1};
            end
        end
        
        function out = getDTypeID(this,s)
            %get current data type id of side s
            out = [];
            str = this.visHandles.(sprintf('flim_param_%s_pop',s)).String;
            if(~ischar(str) && ~isempty(str))
                [~,out] = FLIMXVisGUI.FLIMItem2TypeAndID(str{this.visHandles.(sprintf('flim_param_%s_pop',s)).Value});
            end
        end
        
        function [name, nr] = getSubject(this,s)
            %get current subject name of side s
            name = [];
            if(this.fdt.getNrSubjects(this.getStudy(s),this.getCondition(s)) ~= 0)
                %study/condition does contain subjects
                nr = get(this.visHandles.(sprintf('subject_%s_pop',s)),'Value');
                subs = get(this.visHandles.(sprintf('subject_%s_pop',s)),'String');           
                if(iscell(subs))
                    name = subs{nr};
                else
                    name = subs;
                end
            end
        end
        
        function [name, nr] = getStudy(this,s)
            %get name of current study of side s            
            %out = get(this.visHandles.(sprintf('study_%s_pop',s)),'Value');
            nr = get(this.visHandles.(sprintf('study_%s_pop',s)),'Value');
            str = get(this.visHandles.(sprintf('study_%s_pop',s)),'String');
            if(iscell(str))
                name = str{nr};
            elseif(ischar(str))
                %nothing to do
                name = str;
            else
                nr = 1;
                name = 'Default';
            end
        end
        
        function [name, nr] = getCondition(this,s)
            %get name of current condition of side s
            nr = get(this.visHandles.(sprintf('view_%s_pop',s)),'Value');
            names = get(this.visHandles.(sprintf('view_%s_pop',s)),'String');
            if(ischar(names))
                nr = 1;
                name = names;
            else
                name = names{nr};
            end
        end
        
        function out = getROICoordinates(this,s)
            %get the coordinates of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).getCurROIInfo();
            out = out(:,2:end);
        end
        
        function out = getROIType(this,s)
            %get the type of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).ROIType;
        end
        
        function out = getROISubType(this,s)
            %get the subtype of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).ROISubType;
        end
        
        function out = getROIVicinity(this,s)
            %get the subtype of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).ROIVicinity;
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.statParams;
        end
        
        %% GUI callbacks
        function GUI_cancelButton_Callback(this,hObject,eventdata)
            %try to stop current FDTree operation
            button = questdlg(sprintf('Stop the current operation?'),'FLIMXVis: Stop Operation','Stop','Continue','Continue');
            switch button
                case 'Stop'
                    this.stopFlag = true;
                    %this.fdt.setCancelFlag(true);
            end
        end
        
        function GUI_enableROIDefinitionCheck_Callback(this,hObject,eventdata)
            %en/dis-able mouse motion callbacks
        end
        
        function GUI_sync3DViews_check_Callback(this,hObject,eventdata)
            %en/dis-able synchronization of 3D views
            %left side leads
            this.objHandles.rdo.setDispView(this.objHandles.ldo.getDispView());
            this.objHandles.rdo.updatePlots();
        end
        
        function GUI_syncSubjects_check_Callback(this,hObject,eventdata)
            %en/dis-able synchronization of subjects
            %left side leads initially
            if(hObject.Value)
                this.setSubject('r',this.getSubject('l'));
            end
        end
        
        function GUI_mouseScrollWheel_Callback(this,hObject,eventdata)
            %executes on mouse scroll wheel move in window 
            cp = this.objHandles.ldo.getMyCP(1);
            s = 'l'; %this side
            if(isempty(cp))
                cp = this.objHandles.rdo.getMyCP(1);
                if(isempty(cp))
                    return;
                end
                s = 'r';
            end
            hSlider = this.visHandles.(sprintf('zoom_%s_slider',s));
            %this.objHandles.(sprintf('%sdo',s)).setZoomAnchor(cp);
            hSlider.Value = max(hSlider.Min,min(hSlider.Max,hSlider.Value-hSlider.SliderStep(1)*eventdata.VerticalScrollCount));
            if(hSlider.Value == 1)
                %reset zoom anchor if zoom level = 1
                this.objHandles.(sprintf('%sdo',s)).setZoomAnchor([]);
            end
            this.objHandles.(sprintf('%sdo',s)).makeZoom();
            GUI_mouseMotion_Callback(this,hObject,[]);
        end
        
        function GUI_mouseMotion_Callback(this,hObject,eventdata)
            %executes on mouse move in window 
            oneSec = 1/24/60/60;
            persistent inFunction lastUpdate
            if(~isempty(inFunction) && inFunction < 100)
                inFunction = inFunction+1;
                return
            elseif(~isempty(inFunction) && inFunction >= 100)
                %fallback if function hangs
                tNow = FLIMX.now();
                if(tNow - lastUpdate > 3)
                    %no change since at least 3 seconds -> reset
                    inFunction = [];
                end
            end
            inFunction = 1;  %prevent callback re-entry
            %update at most 100 times per second (every 0.01 sec)
            tNow = FLIMX.now();
            if(~isempty(lastUpdate) && tNow - lastUpdate < 0.010*oneSec) %|| this.dynParams.mouseButtonUp)
                inFunction = [];  %enable callback
                return;
            end
            lastUpdate = tNow;
            %% coordinates
            cpMain = this.objHandles.ldo.getMyCP(1);
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cpMain))
                cpMain = this.objHandles.rdo.getMyCP(1);
                thisSide = 'r';
                otherSide = 'l';
            end
            cpSupp = [];
            if(isempty(cpMain))
                %no hit on main axes, try supp axes
                cpSupp = this.objHandles.ldo.getMyCP(2);
                thisSide = 'l';
                otherSide = 'r';
                if(isempty(cpSupp))
                    cpSupp = this.objHandles.rdo.getMyCP(2);
                    thisSide = 'r';
                    otherSide = 'l';
                end
            end
            pixelMargin = 0;
            %% cursor
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3 || ~isempty(cpSupp))
                if(~isempty(cpSupp))
                    %supp axes
                    cs = this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.getCurCSInfo();
                    cStartClass = this.objHandles.(sprintf('%sdo',thisSide)).colorStartClass;
                    cEndClass = this.objHandles.(sprintf('%sdo',thisSide)).colorEndClass;
                    %cClassWidth = this.objHandles.(sprintf('%sdo',thisSide)).colorClassWidth;
                    if(~(cs(1)) && (abs(cStartClass-cpSupp(1)) <= cEndClass*0.005 || abs(cEndClass-cpSupp(1)) <= cEndClass*0.005))
                        this.visHandles.FLIMXVisGUIFigure.Pointer = 'right';
                    else
                        this.visHandles.FLIMXVisGUIFigure.Pointer = 'cross';
                    end
                else
                    %main axes
                    thisROIObj = this.objHandles.(sprintf('%sROI',thisSide));
                    isLeftButton = strcmp('normal',get(hObject,'SelectionType'));
                    %isempty(this.dynParams.mouseButtonDown) || ~this.dynParams.mouseButtonDown || this.dynParams.mouseButtonDown && isempty(this.dynParams.mouseButtonDownROI) && 
                    if(~isempty(this.dynParams.mouseButtonDown) && this.dynParams.mouseButtonDown && isLeftButton)                        
                        if(this.dynParams.mouseButtonDown > 1)
                            %mouse pointer while changing the ROI size
                            pTypes = FLIMXVisGUI.getROIBorderPointerTypes;
                            this.visHandles.FLIMXVisGUIFigure.Pointer = pTypes{this.dynParams.mouseButtonDown-1};
                        else
                            %mouse move during new ROI
                            this.visHandles.FLIMXVisGUIFigure.Pointer = 'cross';
                        end
                    elseif(~isempty(this.dynParams.mouseButtonDown) && this.dynParams.mouseButtonDown && ~isLeftButton)
                        %mouse move during moving of ROI or moving zoom
                        if(this.dynParams.mouseButtonIsInsideROI && this.visHandles.enableROIDef_check.Value)
                            this.visHandles.FLIMXVisGUIFigure.Pointer = 'fleur';
                        else
                            this.visHandles.FLIMXVisGUIFigure.Pointer = 'hand';
                        end
                    else
                        %no mouse button pressed
                        if(this.visHandles.enableROIDef_check.Value)
                            %mouse pointer at edge of ROI with ROI enabled
                            ROICoord = thisROIObj.getCurROIInfo();
                            this.visHandles.FLIMXVisGUIFigure.Pointer = ROICtrl.mouseOverROIBorder(cpMain,thisROIObj.ROIType,ROICoord(:,2:end),pixelMargin);
                        else
                            %hovering over the axis with ROI def. disabled
                            this.visHandles.FLIMXVisGUIFigure.Pointer = 'cross';
                        end
                    end
                end
            elseif(isempty(cpMain) && isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow');
            end
            %% main axes            
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3)
                otherROIObj = this.objHandles.(sprintf('%sROI',otherSide));
                if(this.dynParams.mouseButtonDown)
                    %user pressed a mouse button
                    rt = this.getROIType(thisSide);
                    if(rt > 1000)
                        %an ROI is active
                        if(isLeftButton)
                            %left button down
                            if(this.dynParams.mouseButtonDown == 1)
                                %new ROI
                                thisROIObj.setEndPoint(flipud(cpMain),false);
                                %draw ROI
                                if(rt > 4000 && rt < 5000)
                                    %polygon
                                    roi = thisROIObj.getCurROIInfo();
                                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),roi(:,2:end),flipud(cpMain),false);
                                else
                                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),flipud(this.dynParams.mouseButtonDownCoord),flipud(cpMain),false);
                                end
                            else
                                %change ROI size                                
                                tmpROI = this.dynParams.mouseButtonDownROI;
                                if(rt > 2000 && rt < 3000)
                                    %rectangle
                                    switch this.dynParams.mouseButtonDown-1
                                        case 1 %right
                                            tmpROI(2,2) = cpMain(1);
                                            this.visHandles.(sprintf('ms_%s_%s_u_edit',thisSide,'x')).String = cpMain(1);
                                        case 2 %topr
                                            tmpROI(:,2) = flipud(cpMain);
                                            thisROIObj.setEndPoint(flipud(cpMain),false);
                                        case 3 %top
                                            tmpROI(1,2) = cpMain(2);
                                            this.visHandles.(sprintf('ms_%s_%s_u_edit',thisSide,'y')).String = cpMain(2);
                                        case 4 %topl
                                            tmpROI(2,1) = cpMain(1);
                                            tmpROI(1,2) = cpMain(2);
                                        case 5 %left
                                            tmpROI(2,1) = cpMain(1);
                                            this.visHandles.(sprintf('ms_%s_%s_lo_edit',thisSide,'x')).String = cpMain(1);
                                        case 6 %botl
                                            tmpROI(:,1) = flipud(cpMain);
                                            thisROIObj.setStartPoint(flipud(cpMain));
                                        case 7 %bottom
                                            tmpROI(1,1) = cpMain(2);
                                            this.visHandles.(sprintf('ms_%s_%s_lo_edit',thisSide,'y')).String = cpMain(2);
                                        case 8 %botr
                                            tmpROI(1,1) = cpMain(2);
                                            tmpROI(2,2) = cpMain(1);
                                    end
                                elseif(rt > 3000 && rt < 4000)
                                    %circle
                                    tmpROI(:,2) = flipud(cpMain);
                                    thisROIObj.setEndPoint(flipud(cpMain),false);
                                elseif(rt > 4000 && rt < 5000)
                                    %polygon
                                    oldPoint = flipud(this.dynParams.mouseButtonDownCoord);
                                    newPoint = cpMain;
                                    oldROI = thisROIObj.getCurROIInfo();
                                    idx = abs(oldPoint(1) - oldROI(1,:)) <= pixelMargin;
                                    hit = abs(oldPoint(2) - oldROI(2,idx)) <= pixelMargin;
                                    if(sum(hit(:)) > 1)
                                        %multiple nodes are within pixelMargin around the current point
                                        idx = find(hit);
                                        absDiff = abs(oldPoint(1) - oldROI(2,idx)) + abs(oldPoint(2) - oldROI(1,idx));
                                        [~,mIdx] = min(absDiff);
                                        hit = false(size(hit));
                                        hit(idx(mIdx)) = true;
                                    elseif(sum(hit(:)) == 1)
                                        idx = find(idx);
                                        hit = idx(hit);
                                    else
                                        hit = [];
                                    end
                                    if(~isempty(hit) && any(hit))
                                        oldROI(:,hit) = flipud(newPoint);
                                        tmpROI = oldROI(:,2:end);
                                        %thisROIObj.updateGUI(tmpROI);
                                    end
                                end
                                this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),tmpROI(:,1),tmpROI(:,2:end),false);
                            end
                        else                            
                            if(this.dynParams.mouseButtonIsInsideROI  && this.visHandles.enableROIDef_check.Value)
                                %right button down: move ROI
                                dTarget = int16(flipud(this.dynParams.mouseButtonDownCoord-cpMain));
                                ROICoord = thisROIObj.getCurROIInfo();
                                ROICoord = ROICoord(:,2:end);
                                dMoved = this.dynParams.mouseButtonDownROI(:,1) - ROICoord(:,1);
                                thisROIObj.moveROI(dTarget-dMoved,false);
                                %get ROI coordinates after moving
                                ROICoord = thisROIObj.getCurROIInfo();
                                %draw ROI
                                rt = thisROIObj.ROIType;
                                if(rt > 3000 && rt < 4000)
                                    %circle
                                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),ROICoord(:,2),ROICoord(:,3),false);
                                else
                                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),ROICoord(:,3:end),ROICoord(:,2),false);
                                end
                                if(thisROIObj.ROIType == otherROIObj.ROIType && strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)) && this.getROIDisplayMode(otherSide) == 1)
                                    %move ROI also on the other side
                                    if(rt > 3000 && rt < 4000)
                                        %circle
                                        this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),ROICoord(:,2),ROICoord(:,3),false);
                                    else
                                        this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),ROICoord(:,3:end),ROICoord(:,2),false);
                                    end
                                end
                            else
                                %move zoom anchor
                                if(this.objHandles.(sprintf('%sdo',thisSide)).mZoomFactor > 1)
                                    dTarget = this.dynParams.mouseButtonDownCoord-cpMain;
                                    this.objHandles.(sprintf('%sdo',thisSide)).setZoomAnchor(this.objHandles.(sprintf('%sdo',thisSide)).zoomAnchor+dTarget);
                                    this.objHandles.(sprintf('%sdo',thisSide)).makeZoom();
                                end
                            end
                        end
                    else
                        %no ROI active
                        if(this.dynParams.mouseButtonDown == 1 && ~isLeftButton && this.objHandles.(sprintf('%sdo',thisSide)).mZoomFactor > 1)
                            %move zoom anchor
                            dTarget = this.dynParams.mouseButtonDownCoord-cpMain;
                            this.objHandles.(sprintf('%sdo',thisSide)).setZoomAnchor(this.objHandles.(sprintf('%sdo',thisSide)).zoomAnchor+dTarget);
                            this.objHandles.(sprintf('%sdo',thisSide)).makeZoom();
                        end
                    end
                end
                %draw mouse overlay on this side in main axes
                this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain(cpMain);
                if(this.getROIDisplayMode(thisSide) == 1 && this.getROIDisplayMode(otherSide) == 1 || this.getROIDisplayMode(thisSide) == 2 && this.getROIDisplayMode(otherSide) == 2 && thisROIObj.ROIType == otherROIObj.ROIType)
                    this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain(cpMain);
                else
                    %other side displays something else, clear possible invalid mouse overlay
                    this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain([]);
                end
            else
                %we are not inside of main axes -> clear possible invalid mouse overlays
                this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain([]);
                this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain([]);
            end            
            %% supp axes
            if(~isempty(cpSupp) && this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value >= 2)
                %in supp axes and either histogram or cross-section is shown
                if(this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value == 2 && this.dynParams.mouseButtonDown)
                    %new color scaling by mouse move while left button down
                    switch this.dynParams.mouseButtonDown
                        case 1
                            this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setColorScale(int16([0 this.dynParams.mouseButtonDownCoord(1) cpSupp(1)]),true);
                        case 2
                            this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setLowerBorder(cpSupp(1),true);
                        case 3
                            this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setUpperBorder(cpSupp(1),true);
                    end
                    [thisDType, thisDTypeNr] = this.getFLIMItem(thisSide);
                    [otherDType, otherDTypeNr] = this.getFLIMItem(otherSide);
                    if(strcmp(thisDType,otherDType) && thisDTypeNr == otherDTypeNr && strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)))
                        this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                    end
                end
            else
                %we are not inside of supp axes -> this will clear a possible invalid mouse overlay
                cpSupp = [];
            end
            %draw mouse overlay on this side in support axes
            this.objHandles.(sprintf('%sdo',thisSide)).drawCPSupp(cpSupp);
            %clear mous overlay on the other side in the support axes
            this.objHandles.(sprintf('%sdo',otherSide)).drawCPSupp([]);
            %% enable callback
            inFunction = [];
        end
                
        function GUI_mouseButtonDown_Callback(this,hObject,eventdata)
            %executes on mouse button down in window
            %this function is now always called by its wrapper: rotate_mouseButtonDownWrapper        
            %% coordinates
            cpMain = this.objHandles.ldo.getMyCP(1);
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cpMain))
                cpMain = this.objHandles.rdo.getMyCP(1);
                thisSide = 'r';
                otherSide = 'l';
            end
            cpSupp = [];
            if(isempty(cpMain))
                %no hit on main axes, try supp axes
                cpSupp = this.objHandles.ldo.getMyCP(2);
                thisSide = 'l';
                otherSide = 'r';
                if(isempty(cpSupp))
                    cpSupp = this.objHandles.rdo.getMyCP(2);
                    thisSide = 'r';
                    otherSide = 'l';
                end
            end
            pixelMargin = 0;
            %% cursor
            isLeftButton = strcmp('normal',get(hObject,'SelectionType'));            
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3 || ~isempty(cpSupp))
                this.dynParams.mouseButtonIsLeft = isLeftButton;
                if(isLeftButton)
                    this.visHandles.FLIMXVisGUIFigure.Pointer = 'cross';
                else
                    if(~isempty(cpMain))
                        this.visHandles.FLIMXVisGUIFigure.Pointer = 'hand';
                    end
                end
            elseif(isempty(cpMain) && isempty(cpSupp))
                this.visHandles.FLIMXVisGUIFigure.Pointer = 'arrow';
                return
            end
            %% main axes
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3)
                %user clicked in a main axes
                ROIBorderID = 0;
                rt = this.getROIType(thisSide);
                if(rt > 1000)
                    %there is an ROI active
                    thisROIObj = this.objHandles.(sprintf('%sROI',thisSide));
                    otherROIObj = this.objHandles.(sprintf('%sROI',otherSide));
                    currentROI = thisROIObj.getCurROIInfo();
                    %check if user hit the border of an ROI
                    [ROIBorderStr, ROIBorderID] = ROICtrl.mouseOverROIBorder(cpMain,rt,currentROI(:,2:end),pixelMargin);
                    %ROI is active and ROI definition enabled
                    if(isLeftButton && this.visHandles.enableROIDef_check.Value && rt > 1000)
                        this.dynParams.mouseButtonDown = ROIBorderID+1;
                        if(rt > 2000 && ~strcmp(ROIBorderStr,'cross'))
                            %this is not an ETDRS grid, change size of existing ROI
                            this.visHandles.FLIMXVisGUIFigure.Pointer = ROIBorderStr;
                        end
                        if(rt > 4000 && rt < 5000 && ~strcmp(ROIBorderStr,'cross'))
                            %move current point of a polygon
                            this.dynParams.mouseButtonDownROI = cpMain;
                        elseif(rt < 4000 && strcmp(ROIBorderStr,'cross'))
                            %left click, start new ROI
                            this.dynParams.mouseButtonDownROI = [];
                            thisROIObj.setStartPoint(flipud(cpMain));
                        end
                        if(size(currentROI,2) >= 2)
                            this.dynParams.mouseButtonDownCoord = cpMain;
                            this.dynParams.mouseButtonDownROI = currentROI(:,2:end);
                        else
                            this.dynParams.mouseButtonDownCoord = [];
                            this.dynParams.mouseButtonDownROI = [];
                        end
                    elseif(~isLeftButton)
                        %right click: move ROI or zoom anchor
                        this.dynParams.mouseButtonDown = 1;
                        %check if inside ROI
                        isInsideROI = false;
                        if(rt > 1000 && rt < 2000)
                            %for the ETDRS grid the pixel scaling is required -> obtain it and simulate a circle with its outer ring
                            hfd = this.objHandles.(sprintf('%sdo',thisSide)).gethfd;
                            if(~isempty(hfd{1}))
                                hfd = hfd{1};
                                fi = hfd.getFileInfoStruct();
                                if(~isempty(fi))
                                    res = fi.pixelResolution;
                                    rOuter = int16([(6000/res/2); 0]);
                                    isInsideROI = ROICtrl.mouseInsideROI(cpMain,4,[currentROI(:,2) currentROI(:,2)+rOuter]);
                                end
                            end
                        else
                            isInsideROI = ROICtrl.mouseInsideROI(cpMain,rt,currentROI(:,2:end));
                        end
                        if(isInsideROI && this.visHandles.enableROIDef_check.Value)
                            this.visHandles.FLIMXVisGUIFigure.Pointer = 'fleur';
                        end
                        this.dynParams.mouseButtonIsInsideROI = isInsideROI;
                        this.dynParams.mouseButtonDownCoord = cpMain;
                        this.dynParams.mouseButtonDownROI = currentROI(:,2:end);
                    end
                else
                    %no ROI on display
                    this.dynParams.mouseButtonDown = 1;
                    this.dynParams.mouseButtonDownCoord = cpMain;
                end
                if(isLeftButton && this.getROIType(thisSide) < 4000 && ROIBorderID == 1)
                    %draw current point and ROI in both main axes (empty cp deletes old lines)
                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),flipud(cpMain),flipud(cpMain),false);
                    this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain(cpMain);
                    if(thisROIObj.ROIType == otherROIObj.ROIType && strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)) && this.getROIDisplayMode(otherSide) == 1)
                        this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),flipud(cpMain),flipud(cpMain),false);
                        this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain(cpMain);
                    end
                end
                return
            elseif(~isempty(cpMain) && this.getROIDisplayMode(thisSide) == 3)
                %3D plot -> nothing to do
                return
            end
            %% supp axes
            if(isempty(cpSupp) || this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value ~= 2 || this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.check)
                return
            end
            this.dynParams.mouseButtonIsLeft = isLeftButton;
            if(isLeftButton)
                cStartClass = this.objHandles.(sprintf('%sdo',thisSide)).colorStartClass;
                cEndClass = this.objHandles.(sprintf('%sdo',thisSide)).colorEndClass;
                %this.dynParams.mouseButtonUp = false;
                if(abs(cEndClass-cpSupp(1)) <= cEndClass*0.005)
                    %user clicked at right border
                    this.dynParams.mouseButtonDown = 3;
                    this.dynParams.mouseButtonDownCoord = cStartClass;
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setUpperBorder(cpSupp(1),true);
                elseif(abs(cStartClass-cpSupp(1)) <= cEndClass*0.005)
                    %user clicked at left border
                    this.dynParams.mouseButtonDown = 2;
                    this.dynParams.mouseButtonDownCoord = cEndClass;
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setLowerBorder(cpSupp(1),true);
                else
                    %user clicked not at a border to start a whole new color scaling
                    this.dynParams.mouseButtonDown = 1;
                    this.dynParams.mouseButtonDownCoord = cpSupp;
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setLowerBorder(cpSupp(1),true);
                end
                this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                this.objHandles.(sprintf('%sdo',thisSide)).drawCPSupp(cpSupp);
                this.objHandles.(sprintf('%sdo',otherSide)).drawCPSupp([]);            
            end
        end
        
        function GUI_mouseButtonUp_Callback(this,hObject,eventdata)
            %executes on mouse button up in window
            %this function is now always called by its wrapper: rotate_mouseButtonUpWrapper
            %this.dynParams.mouseButtonUp = true;
            cpMain = this.objHandles.ldo.getMyCP(1);
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cpMain))
                cpMain = this.objHandles.rdo.getMyCP(1);
                thisSide = 'r';
                otherSide = 'l';
            end
            cpSupp = [];
            if(isempty(cpMain))
                %no hit on main axes, try supp axes
                cpSupp = this.objHandles.ldo.getMyCP(2);
                thisSide = 'l';
                otherSide = 'r';
                if(isempty(cpSupp))
                    cpSupp = this.objHandles.rdo.getMyCP(2);
                    thisSide = 'r';
                    otherSide = 'l';
                end
            end
            %% cursor
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3 || ~isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
            elseif(isempty(cpMain) && isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow'); 
            end
            %% main axes
            %draw mouse overlay in both main axes (empty cp deletes old overlays)
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3)
                if(isempty(cpSupp) && this.getROIType(thisSide) > 1000 && this.visHandles.enableROIDef_check.Value)
                    thisROIObj = this.objHandles.(sprintf('%sROI',thisSide));
                    otherROIObj = this.objHandles.(sprintf('%sROI',otherSide));
                    if(~isempty(cpMain))
%                         cpMain(1,1) = thisROIObj.myHFD.xLbl2Pos(cpMain(1,1));
%                         cpMain(2,1) = thisROIObj.myHFD.yLbl2Pos(cpMain(2,1));
                        if(this.dynParams.mouseButtonIsLeft)%strcmp('normal',get(hObject,'SelectionType'))
                            %left click
                            if(this.dynParams.mouseButtonDown == 1)
                                %new ROI
                                thisROIObj.setEndPoint(flipud(cpMain),true);
                            else
                                %change ROI size
                                tmpROI = this.dynParams.mouseButtonDownROI;
                                rt = thisROIObj.ROIType;
                                if(rt > 2000 && rt < 3000)
                                    %rectangle
                                    switch this.dynParams.mouseButtonDown-1
                                        case 1 %right
                                            tmpROI(2,2) = cpMain(1);
                                        case 2 %topr
                                            tmpROI(:,2) = flipud(cpMain);
                                        case 3 %top
                                            tmpROI(1,2) = cpMain(2);
                                        case 4 %topl
                                            tmpROI(2,1) = cpMain(1);
                                            tmpROI(1,2) = cpMain(2);
                                        case 5 %left
                                            tmpROI(2,1) = cpMain(1);
                                        case 6 %botl
                                            tmpROI(:,1) = flipud(cpMain);
                                        case 7 %bottom
                                            tmpROI(1,1) = cpMain(2);
                                        case 8 %botr
                                            tmpROI(1,1) = cpMain(2);
                                            tmpROI(2,2) = cpMain(1);
                                    end
                                elseif(rt > 3000 && rt < 4000)
                                    %circle
                                    tmpROI(:,2) = flipud(cpMain);
                                elseif(rt > 4000 && rt < 5000) %polygon
                                    pixelMargin = 0;
                                    oldPoint = flipud(this.dynParams.mouseButtonDownCoord);
                                    newPoint = cpMain;
                                    oldROI = thisROIObj.getCurROIInfo();
                                    idx = abs(oldPoint(1) - oldROI(1,:)) <= pixelMargin;
                                    hit = abs(oldPoint(2) - oldROI(2,idx)) <= pixelMargin;
                                    if(sum(hit(:)) > 1)
                                        %multiple nodes are within pixelMargin around the current point
                                        idx = find(hit);
                                        absDiff = abs(oldPoint(1) - oldROI(2,idx)) + abs(oldPoint(2) - oldROI(1,idx));
                                        [~,mIdx] = min(absDiff);
                                        hit = false(size(hit));
                                        hit(idx(mIdx)) = true;
                                    elseif(sum(hit(:)) == 1)
                                        idx = find(idx);
                                        hit = idx(hit);
                                    else
                                        hit = [];
                                    end
                                    if(~isempty(hit) && any(hit))
                                        oldROI(:,hit) = flipud(newPoint);
                                        this.visHandles.(sprintf('roi_%s_table',thisSide)).Data = num2cell(oldROI(:,2:end));
                                        thisROIObj.tableEditCallback([]);
                                    end
                                end
                                if(rt < 4000)
                                    %only for rectangles and circles
                                    thisROIObj.setStartPoint(tmpROI(:,1));
                                    thisROIObj.setEndPoint(tmpROI(:,2),true);
                                end
                            end
                        else
                            %right click
                            if(~isempty(this.dynParams.mouseButtonDownCoord))
                                if(this.dynParams.mouseButtonIsInsideROI)
                                    %move ROI
                                    dTarget = int16(flipud(this.dynParams.mouseButtonDownCoord-cpMain));
                                    ROICoord = thisROIObj.getCurROIInfo();
                                    ROICoord = ROICoord(:,2:end);
                                    dMoved = this.dynParams.mouseButtonDownROI(:,1) - ROICoord(:,1);
                                    thisROIObj.moveROI(dTarget-dMoved,true);
                                else
                                    %move zoom anchor
                                    if(this.objHandles.(sprintf('%sdo',thisSide)).mZoomFactor > 1)
                                        dTarget = this.dynParams.mouseButtonDownCoord-cpMain;
                                        this.objHandles.(sprintf('%sdo',thisSide)).setZoomAnchor(this.objHandles.(sprintf('%sdo',thisSide)).zoomAnchor+dTarget);
                                        this.objHandles.(sprintf('%sdo',thisSide)).makeZoom();
                                    end
                                end
                            end
                        end
                    end %if(~isempty(cpMain))
                    otherROIObj.updateGUI([]);
                    this.myStatsGroupComp.clearResults();
                    if(this.fdt.isArithmeticImage(this.getStudy('r'),this.getFLIMItem('r')))
                        tZA = this.objHandles.rdo.zoomAnchor;
                        this.objHandles.rdo.sethfdMain([]);
                        this.objHandles.rdo.setZoomAnchor(tZA);
                    end
                    this.objHandles.rdo.updatePlots(); %this will also update the statistics table
                    if(this.fdt.isArithmeticImage(this.getStudy('l'),this.getFLIMItem('l')))
                        tZA = this.objHandles.ldo.zoomAnchor;
                        this.objHandles.ldo.sethfdMain([]);
                        this.objHandles.ldo.setZoomAnchor(tZA);
                    end
                    this.objHandles.ldo.updatePlots(); %this will also update the statistics table
                    %draw mouse overlay on this side in main axes
                    this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain(cpMain);
                    if(this.getROIDisplayMode(thisSide) == 1 && this.getROIDisplayMode(otherSide) == 1 || this.getROIDisplayMode(thisSide) == 2 && this.getROIDisplayMode(otherSide) == 2 && thisROIObj.ROIType == otherROIObj.ROIType)
                        this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain(cpMain);
                    else
                        %other side displays something else, clear possible invalid mouse overlay
                        this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain([]);
                    end
                elseif(~isempty(cpMain) && isempty(cpSupp) && ~this.visHandles.enableROIDef_check.Value || this.getROIType(thisSide) < 1000)
                    %click in main axis with ROI definition disabled or no ROI active
                    if(~this.dynParams.mouseButtonIsLeft)
                        %move zoom anchor
                        if(this.objHandles.(sprintf('%sdo',thisSide)).mZoomFactor > 1)
                            dTarget = this.dynParams.mouseButtonDownCoord-cpMain;
                            this.objHandles.(sprintf('%sdo',thisSide)).setZoomAnchor(this.objHandles.(sprintf('%sdo',thisSide)).zoomAnchor+dTarget);
                            this.objHandles.(sprintf('%sdo',thisSide)).makeZoom();
                        end
                    end                        
                end
                this.dynParams.mouseButtonDown = 0;
                this.dynParams.mouseButtonDownCoord = [];
                this.dynParams.mouseButtonDownROI = [];
                this.dynParams.mouseButtonIsLeft = false;
                this.dynParams.mouseButtonIsInsideROI = false;
            end
            %% supp axes
            %this.dynParams.mouseButtonUp = false;
            if(~isempty(cpMain) || this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value ~= 2)
                return
            end
            if(this.dynParams.mouseButtonIsLeft)
                if(this.dynParams.mouseButtonDown)
                    if(~isempty(cpSupp))
                        %we only have a valid current point inside of axes, if mouse button is released outside, the last valid cp from mouseMotion is used
                        switch this.dynParams.mouseButtonDown
                            case 1 %whole new color scaling
                                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setColorScale(int16([0 this.dynParams.mouseButtonDownCoord(1) cpSupp(1)]),true);
                            case 2 %user moved start class
                                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setColorScale(int16([0 cpSupp(1) this.dynParams.mouseButtonDownCoord(1)]),true);
                            case 3 %user moved end class
                                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setColorScale(int16([0 this.dynParams.mouseButtonDownCoord(1) cpSupp(1)]),true);
                        end
                    end
                    this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                end
            else
                %right click
                if(~isempty(cpSupp))
                    %reset color scaling to auto only if click happened inside of axes
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.forceAutoScale(this.getROIDisplayMode(thisSide) > 1);
                end
                this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
            end            
            this.objHandles.(sprintf('%sdo',thisSide)).drawCPSupp(cpSupp);
            this.objHandles.(sprintf('%sdo',otherSide)).drawCPSupp([]);
            this.dynParams.mouseButtonDown = 0;
            this.dynParams.mouseButtonDownCoord = [];
            this.dynParams.mouseButtonDownROI = [];
            this.dynParams.mouseButtonIsLeft = false;
            this.dynParams.mouseButtonIsInsideROI = false;
        end
        
        function GUI_studySet_Callback(this,hObject,eventdata)
            %select study
            thisSide = 'r';
            otherSide = 'l';
            if(strcmp(get(hObject,'Tag'),'study_l_pop'))
                thisSide = 'l';
                otherSide = 'r';
            end
            if(this.visHandles.syncSubjects_check.Value)
                this.setupGUI();
                if(~this.setSubject(thisSide,this.getSubject(otherSide)))
                    this.updateGUI(thisSide);
                end
            else
                this.setupGUI();
                this.updateGUI(thisSide);
            end
        end
        
        function GUI_conditionSet_Callback(this,hObject,eventdata)
            %select condition
            thisSide = 'r';
            otherSide = 'l';
            if(strcmp(get(hObject,'Tag'),'view_l_pop'))
                thisSide = 'l';
                otherSide = 'r';
            end
            if(this.visHandles.syncSubjects_check.Value)
                this.setupGUI();
                if(~this.setSubject(otherSide,this.getSubject(thisSide)))
                    this.updateGUI(otherSide);
                end
            else
                this.setupGUI();
                this.updateGUI(thisSide);
            end
        end
                        
        function GUI_subjectPop_Callback(this,hObject,eventdata)
            %select subject
            thisSide = 'r';
            otherSide = 'l';
            if(strcmp(get(hObject,'Tag'),'subject_l_pop'))
                thisSide = 'l';
                otherSide = 'r';
            end
            %save study info to disk
            this.FLIMXObj.fdt.saveStudy(this.getStudy(thisSide));
            %if enabled by user, find current subject of this side on the other side and set it
            this.setupGUI();
            this.updateGUI(thisSide);
            if(this.visHandles.syncSubjects_check.Value)
                this.setSubject(otherSide,this.getSubject(thisSide));
%                 dStr = this.fdt.getAllSubjectNames(curStudy,curCondition);
%                 if(~isempty(dStr))
%                     set(this.visHandles.(sprintf('subject_%s_pop',s)),'String',dStr,'Value',min(get(this.visHandles.(sprintf('subject_%s_pop',s)),'Value'),nrSubs));
%                 else
%                     set(this.visHandles.(sprintf('subject_%s_pop',s)),'String','dataset','Value',1);
%                 end
%                 this.myStatsGroupComp.setupGUI();
%                 curSubject = this.getSubject(s);
            end
        end
        
        function GUI_subjectButton_Callback(this,hObject,eventdata)
            %switch subject
            switch get(hObject,'Tag')
                case 'subject_l_dec_button'
                    set(this.visHandles.subject_l_pop,'Value',max(1,get(this.visHandles.subject_l_pop,'Value')-1));
                    thisSide = 'l';
                    otherSide = 'r';
                case 'subject_l_inc_button'
                    set(this.visHandles.subject_l_pop,'Value',min(length(get(this.visHandles.subject_l_pop,'String')),get(this.visHandles.subject_l_pop,'Value')+1));
                    thisSide = 'l';
                    otherSide = 'r';
                case 'subject_r_dec_button'
                    set(this.visHandles.subject_r_pop,'Value',max(1,get(this.visHandles.subject_r_pop,'Value')-1));
                    thisSide = 'r';
                    otherSide = 'l';
                case 'subject_r_inc_button'
                    set(this.visHandles.subject_r_pop,'Value',min(length(get(this.visHandles.subject_r_pop,'String')),get(this.visHandles.subject_r_pop,'Value')+1));
                    thisSide = 'r';
                    otherSide = 'l';
                otherwise
                    return
            end
            %save study info to disk
            this.FLIMXObj.fdt.saveStudy(this.getStudy(thisSide));
            this.setupGUI();
            this.updateGUI(thisSide);
            if(this.visHandles.syncSubjects_check.Value)
                this.setSubject(otherSide,this.getSubject(thisSide));
            end
        end
        
        function GUI_FLIMParamPop_Callback(this,hObject,eventdata)
            %select FLIMItem
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'flim_param_l_pop'))
                s = 'l';
            end
            this.updateGUI(s);
            this.objHandles.(sprintf('%sdo',s)).updateColorbar();
%             this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
%             this.objHandles.(sprintf('%sROI',s)).updateGUI([]);
%             this.objHandles.(sprintf('%sdo',s)).updatePlots();
        end
        
        function GUI_varModePop_Callback(this,hObject,eventdata)
            %select uni- or multivariate mode
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'var_mode_l_pop'))
                s = 'l';
            end
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_dimensionPop_Callback(this,hObject,eventdata)
            %select 2D overview, 2D or 3D visualization
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'dimension_l_pop'))
                s = 'l';
            end
            if(this.fdt.getNrSubjects(this.getStudy(s),this.getCondition(s)) < 1)
                return
            end
            if(this.objHandles.(sprintf('%sdo',s)).myColorScaleObj.check)
                this.objHandles.(sprintf('%sdo',s)).myColorScaleObj.forceAutoScale(hObject.Value > 1);
            else
                this.objHandles.(sprintf('%sdo',s)).updatePlots();
            end
            %this.updateGUI([]);
        end
        
        function GUI_channelPop_Callback(this,hObject,eventdata)
            %select channel
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'channel_l_pop'))
                s = 'l';
            end
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_scalePop_Callback(this,hObject,eventdata)
            %select linear or log10 scaling
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'scale_l_pop'))
                s = 'l';
            end
            this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
            this.objHandles.(sprintf('%sROI',s)).updateGUI([]);
            this.objHandles.(sprintf('%sdo',s)).updatePlots();
        end
        
        function GUI_zoom_Callback(this,hObject,eventdata)
            %zoom
            s = 'r';
            if(strcmp(hObject.Tag,'zoom_l_slider'))
                s = 'l';
            end
            if(hObject.Value == 1)
                %reset zoom anchor if zoom level = 1
                this.objHandles.(sprintf('%sdo',s)).setZoomAnchor([]);
            end
            this.objHandles.(sprintf('%sdo',s)).makeZoom();
        end
        
        function GUI_crossSection_Callback(this,hObject,eventdata)
            %access crossSection controls
            if(this.fdt.getNrSubjects(this.getStudy('l'),this.getCondition('l')) < 1)
                return
            end
            ax = 'x';
            tag = get(hObject,'Tag');
            if(contains(tag,'y'))
                ax = 'y';
            end
            if(contains(tag,'edit'))
                this.objHandles.(sprintf('crossSection%s',ax)).editCallback();
            elseif(contains(tag,'check'))
                this.objHandles.(sprintf('crossSection%s',ax)).checkCallback();
            else
                this.objHandles.(sprintf('crossSection%s',ax)).sliderCallback();
            end
            this.objHandles.rdo.updatePlots();
            this.objHandles.ldo.updatePlots();
        end
        
        function GUI_colorScale_Callback(this,hObject,eventdata)
            %adjust the color scaling
            thisSide = 'r';
            otherSide = 'l';
            tag = get(hObject,'Tag');
            if(contains(tag,'_l_'))
                thisSide = 'l';
                otherSide = 'r';
            end
            if(contains(tag,'edit'))
                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.editCallback();
                if(~isempty(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1}) && this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1} == this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1})
                    this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                end
            elseif(contains(tag,'check'))
                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.checkCallback(this.getROIDisplayMode(thisSide) > 1);
                this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
            elseif(contains(tag,'button'))
                if(contains(tag,'in'))
                    this.objHandles.(sprintf('%sdo',thisSide)).zoomSuppXScale('in');
                    if(~isempty(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1}) && isequal(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1}, this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1}))
                        this.objHandles.(sprintf('%sdo',otherSide)).zoomSuppXScale(this.objHandles.(sprintf('%sdo',thisSide)).mySuppXZoomScale);
                    end
                elseif(contains(tag,'out'))
                    this.objHandles.(sprintf('%sdo',thisSide)).zoomSuppXScale('out');
                    if(~isempty(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1}) && isequal(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1}, this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1}))
                        this.objHandles.(sprintf('%sdo',otherSide)).zoomSuppXScale(this.objHandles.(sprintf('%sdo',thisSide)).mySuppXZoomScale);
                    end
                elseif(contains(tag,'misc'))
                    csInfo = this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.getCurCSInfo();
                    ch = this.getChannel(thisSide);
                    sp1 = sprintf('Set ''%s %d'' color scaling for all subjects of channel %d\n\n',this.getDType(thisSide),this.getDTypeID(thisSide),ch);
                    if(strcmp(this.getCondition(thisSide),FDTree.defaultConditionName))
                        %all subjects
                        sp2 = sprintf('in study ''%s''\n\n',this.getStudy(thisSide));
                    else
                        %condition
                        sp2 = sprintf('in study ''%s'' condition ''%s''\n\n',this.getStudy(thisSide),this.getCondition(thisSide));
                    end
                    if(csInfo(1))
                        %auto color scaling
                        sp3 = sprintf('to automatic?');
                    else
                        %custom color scaling
                        csInfoStr = FLIMXFitGUI.num4disp(csInfo);
                        sp3 = sprintf('to %s - %s?',csInfoStr{2},csInfoStr{3});
                    end
                    choice = questdlg([sp1,sp2,sp3],'Set Color Scaling?','Yes','No','Yes');
                    switch choice
                        case 'Yes'
                            this.fdt.setResultColorScaling(this.getStudy(thisSide),this.getCondition(thisSide),this.getChannel(thisSide),this.getDType(thisSide),this.getDTypeID(thisSide),csInfo);
                            this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                    end                    
                end
                return
            end
        end
        
        function GUI_roi_Callback(this,hObject,eventdata)
            %change roi size in x, y or z direction
            thisSide = 'r'; %side which activated the control
            otherSide = 'l'; %side we have to update to the new values
            %find side/axes
            tag = get(hObject,'Tag');
            if(contains(tag,'_l_'))
                thisSide = 'l';
                otherSide = 'r';
            end
            %find dimension
            if(contains(tag,'_x_'))
                dim = 'x';
            elseif(contains(tag,'_y_'))
                dim = 'y';
            else
                dim = 'z';
            end
            %lower or upper bound?
            if(contains(tag,'_lo_'))
                bnd = 'lo';
            else
                bnd = 'u';
            end
            %find control type
            if(contains(tag,'edit'))
                if(strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sZScale',thisSide)).editCallback(dim,bnd);
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.checkCallback(this.getROIDisplayMode(thisSide) > 1);
                else
                    this.objHandles.(sprintf('%sROI',thisSide)).editCallback(dim,bnd);
                end
            elseif(contains(tag,'roi_group'))
                if(isempty(this.objHandles.ROIGM) || ~isprop(this.objHandles.ROIGM,'FLIMXROIGroupManagerUIFigure') || ~isgraphics(this.objHandles.ROIGM.FLIMXROIGroupManagerUIFigure))
                    this.objHandles.ROIGM = GUI_ROIGroups(this,this.getStudy(thisSide));
                else
                    this.objHandles.ROIGM.myStartupFcn(this,this.getStudy(thisSide));
                end
            elseif(length(tag) == 11 && contains(tag,'table'))
                this.objHandles.(sprintf('%sROI',thisSide)).tableEditCallback(eventdata);
                this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
            elseif(contains(tag,'roi_table_clearLast'))
                this.objHandles.(sprintf('%sROI',thisSide)).buttonClearLastCallback();
                this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
            elseif(contains(tag,'roi_table_clearAll'))
                this.objHandles.(sprintf('%sROI',thisSide)).buttonClearAllCallback();
                this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
            elseif(contains(tag,'button') && ~contains(tag,{'roi_table_clearAll','roi_add','roi_delete','roi_apply'}))
                if(contains(tag,'_dec_'))
                    target = 'dec';
                else
                    target = 'inc';
                end
                if(strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sZScale',thisSide)).buttonCallback(dim,bnd,target);
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.checkCallback(this.getROIDisplayMode(thisSide) > 1);
                else
                    this.objHandles.(sprintf('%sROI',thisSide)).buttonCallback(dim,bnd,target);
                end
            elseif(contains(tag,'button') && contains(tag,'roi_add'))
                this.objHandles.(sprintf('%sROI',thisSide)).addNewROI();
                this.objHandles.(sprintf('%sROI',otherSide)).setupGUI();
                this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
            elseif(contains(tag,'button') && contains(tag,'roi_delete'))
                rt = this.getROIType(thisSide);
                ROIStr = ROICtrl.ROIType2ROIItem(rt);
                button = questdlg(sprintf('Delete or reset current region of interest (ROI) ''%s''?\n\nCaution!\n\nReseting ''%s'' will set the ROI to its default undefined state in the current subject (%s).\n\nDeleting ''%s'' will delete the ROI from all subjects of the current study (%s)!',...
                    ROIStr,ROIStr,this.getSubject(thisSide),ROIStr,this.getStudy(thisSide)),'FLIMX: Delete or Reset ROI','Delete','Reset','Cancel','Reset');
                switch button
                    case 'Delete'
                        this.objHandles.(sprintf('%sROI',thisSide)).deleteROI();
                        this.objHandles.(sprintf('%sROI',otherSide)).setupGUI();
                        this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
                    case 'Reset'
                        this.objHandles.(sprintf('%sROI',thisSide)).resetROI();
                        this.objHandles.(sprintf('%sROI',thisSide)).updateGUI([]);
                        this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
                    case 'Cancel'
                        return
                end
            elseif(contains(tag,'button') && contains(tag,'roi_apply'))
                hfd = this.objHandles.(sprintf('%sROI',thisSide)).myHFD;
                if(isempty(hfd))
                    return
                end
                ROIInfo = this.objHandles.(sprintf('%sROI',thisSide)).getCurROIInfo(true); %ROI coordinates are in matrix positions
                if(ROIInfo(1,1) == 0)
                    %no ROI selected
                    return
                end                
                studyName = this.getStudy(thisSide);
                conditionName = this.getCondition(thisSide);
                if(strncmp(hfd.dType,'ConditionMVGroup',16))
                    %this is a merged MVGroup -> apply the ROI coordinates to the MVGoup of the subjects
                    dType = hfd.dType(10:end);
                else
                    dType = hfd.dType;
                end
                sp1 = sprintf('Set ROI ''%s'' definition for all subjects\n\n',ROICtrl.ROIType2ROIItem(ROIInfo(1,1)));
                if(strcmp(conditionName,FDTree.defaultConditionName))
                    %all subjects
                    sp2 = sprintf('in study ''%s''\n\n',studyName);
                else
                    %condition
                    sp2 = sprintf('in study ''%s'' condition ''%s''\n\n',studyName,conditionName);
                end
                sp3 = sprintf('to the current definiton?\n\nTHIS WILL REPLACE ANY EXISTING DEFINITION FOR THIS ROI!');
                choice = questdlg([sp1,sp2,sp3],'Set ROI Definition?','Yes','No','Yes');
                switch choice
                    case 'No'
                        return
                end
                subNames = this.fdt.getAllSubjectNames(studyName,conditionName);
                nSubjects = length(subNames);
                this.updateLongProgress(0.01,'0.0%% - ETA: -');
                tStart = clock;
                for i = 1:length(subNames)
                    sHFD = this.fdt.getFDataObj(studyName,subNames{i},hfd.channel,dType,hfd.id,hfd.sType);
                    if(isempty(sHFD) || hfd == sHFD)
                        continue
                    end
                    sROIInfo = ROIInfo;
                    %convert label ROI positions to matrix ROI positions
                    sROIInfo(1,2:end) = sHFD.yLbl2Pos(sROIInfo(1,2:end));
                    sROIInfo(2,2:end) = sHFD.xLbl2Pos(sROIInfo(2,2:end));
                    this.fdt.setResultROICoordinates(studyName,subNames{i},dType,hfd.id,ROIInfo(1,1),sROIInfo);
                    %update progress bar
                    [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(nSubjects-i)); %mean cputime for finished runs * cycles left
                    minutes = minutes + hours * 60; %unlikely to take hours
                    this.updateLongProgress(i/nSubjects,sprintf('%02.1f%% - ETA: %02.0fm %02.0fs',i/nSubjects*100,minutes,secs));
                end
                this.updateLongProgress(0,'');
                this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                %this.objHandles.(sprintf('%sROI',otherSide)).setupGUI();
                this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
            elseif(contains(tag,'popup'))
                if(contains(tag,'roi_subtype_'))
                    type = 'main';
                else
                    type = 'sub';
                end
                this.objHandles.(sprintf('%sROI',thisSide)).popupCallback(type);
            else %check
                this.objHandles.(sprintf('%sZScale',thisSide)).checkCallback(dim);
                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.checkCallback(this.getROIDisplayMode(thisSide) > 1);
            end
            if(this.getROIDisplayMode(thisSide) > 1 && this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.check)
                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.forceAutoScale(true);
            end
            %update ROI controls on other side
            if(contains(tag,'type_'))
                this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
            else
                if(~strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
                    %update crossSections only for x and y
                    this.objHandles.(sprintf('crossSection%s',dim)).checkCallback();
                else
                    this.objHandles.(sprintf('%sZScale',otherSide)).updateGUI([]);
                end
            end
            %make sure FDisplay rebuild merged statistics
            this.objHandles.ldo.sethfdSupp([]);
            this.objHandles.rdo.sethfdSupp([]);
            this.myStatsGroupComp.clearResults();
            this.objHandles.rdo.updatePlots();
            this.objHandles.ldo.updatePlots();
        end
        
        function GUI_suppAxesPop_Callback(this,hObject,eventdata)
            %select crossSection or histogram for supplemental display
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'supp_axes_l_pop'))
                s = 'l';
            end
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_suppAxesHistPop_Callback(this,hObject,eventdata)
            %select crossSection or histogram for supplemental display
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'supp_axes_hist_l_pop'))
                s = 'l';
            end
            this.updateGUI(s);
        end
        
        function GUI_suppAxesScalePop_Callback(this,hObject,eventdata)
            %select linear or log10 scaling for crossSections in supplemental plot
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'supp_axes_scale_l_pop'))
                s = 'l';
            end
            this.objHandles.(sprintf('%sdo',s)).makeSuppPlot();
        end
                
        function menuExportExcel_Callback(this,hObject,eventdata)
            %
            tag = get(hObject,'Tag');
            side = 'l';
            if(contains(tag,'R'))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(contains(tag,'B'))
                pType = 'supp'; %supp. plot
            end
            switch pType
                case 'main'
                    ex = this.objHandles.(sprintf('%sdo',side)).(sprintf('%sExportXls',pType));
                case 'supp'
                    ex = this.objHandles.(sprintf('%sdo',side)).(sprintf('%sExport',pType));
            end
            if(isempty(ex))
                return
            end
            [file,path] = uiputfile({'*.xlsx','Excel file (*.xlsx)';'*.xls','Excel 97-2003 file (*.xls)'},'Export Data in Excel Fileformat...');
            if ~file ; return ; end
            fn = fullfile(path,file);
            %             [y x] = size(ex);
            %             if(x > y)
            %                 ex = ex';
            %             end
            dType = get(this.visHandles.(sprintf('flim_param_%s_pop',side)),'String');
            dType = char(dType(get(this.visHandles.(sprintf('flim_param_%s_pop',side)),'Value'),:));
            if(strcmp(pType,'supp'))
                eType = get(this.visHandles.(sprintf('supp_axes_%s_pop',side)),'String');
                eType = char(eType(get(this.visHandles.(sprintf('supp_axes_%s_pop',side)),'Value'),:));
                sheetName = [dType '_' eType];
            else
                sheetName = dType;
            end
            exportExcel(fn,double(ex),'','',sheetName,'');
        end
        
        function GUI_intOverlay_Callback(this,hObject,eventdata)
            %
            s = 'l';
            %find side/axes
            tag = get(hObject,'Tag');
            if(~contains(tag,'_l_'))
                s = 'r';
            end
            if(this.fdt.getNrSubjects(this.getStudy(s),this.getCondition(s)) < 1)
                return
            end
            %check if button was pressed
            if(contains(tag,'_button'))
                if(contains(tag,'_dec_'))
                    %decrease brightness
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'String',...
                        num2str(max(str2double(get(this.visHandles.(sprintf('IO_%s_edit',s)),'String'))-0.1,0)));
                else
                    %increase brightness
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'String',...
                        num2str(min(str2double(get(this.visHandles.(sprintf('IO_%s_edit',s)),'String'))+0.1,1)));
                end
            end
            this.objHandles.(sprintf('%sdo',s)).sethfdMain([]); %for log10 scaling
            this.objHandles.(sprintf('%sdo',s)).updatePlots();
        end
        
        function GUI_conditionColorSelection_Callback(this,hObject,eventdata)
            %change study condition color
            s = 'l';
            if(~strcmp(sprintf('study_color_%s_button',s),get(hObject,'Tag')))
                s = 'r';
            end
            cs = GUI_Colorselection(this.fdt.getConditionColor(this.getStudy(s),this.getCondition(s)));
            if(length(cs) == 3)
                %set new color
                this.fdt.setConditionColor(this.getStudy(s),this.getCondition(s),cs);
                this.setupGUI();
                this.updateGUI([]);
            end
        end
        
        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            switch this.generalParams.windowSize
                case 1
                    this.visHandles = FLIMXVisGUIFigureMedium();
                case 2
                    this.visHandles = FLIMXVisGUIFigureSmall();
                case 3
                    this.visHandles = FLIMXVisGUIFigureLarge();
            end
            figure(this.visHandles.FLIMXVisGUIFigure);
            %set callbacks
            set(this.visHandles.FLIMXVisGUIFigure,'Units','Pixels');
            %popups
            set(this.visHandles.enableROIDef_check,'Callback',@this.GUI_enableROIDefinitionCheck_Callback,'Value',0,'TooltipString','Enable ROI definition by mouse pointer (no 3D rotation possible if enabled)');
            set(this.visHandles.sync3DViews_check,'Callback',@this.GUI_sync3DViews_check_Callback,'Value',0,'TooltipString','Synchronize 3D views on left and right side');
            set(this.visHandles.syncSubjects_check,'Callback',@this.GUI_syncSubjects_check_Callback,'Value',0,'TooltipString','Synchronize subjects by their names on left and right side (if possible)');
            %main axes
            set(this.visHandles.subject_l_pop,'Callback',@this.GUI_subjectPop_Callback,'TooltipString','Select current subject of the left side');
            set(this.visHandles.subject_r_pop,'Callback',@this.GUI_subjectPop_Callback,'TooltipString','Select current subject of the right side');
            set(this.visHandles.subject_l_dec_button,'FontName','Symbol','String',char(173),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to previous subject on the left side');
            set(this.visHandles.subject_l_inc_button,'FontName','Symbol','String',char(175),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to next subject on the left side');
            set(this.visHandles.subject_r_dec_button,'FontName','Symbol','String',char(173),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to previous subject on the right side');
            set(this.visHandles.subject_r_inc_button,'FontName','Symbol','String',char(175),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to next subject on the right side');
            set(this.visHandles.flim_param_l_pop,'Callback',@this.GUI_FLIMParamPop_Callback,'TooltipString','Select FLIM parameter to display on the left side');
            set(this.visHandles.flim_param_r_pop,'Callback',@this.GUI_FLIMParamPop_Callback,'TooltipString','Select FLIM parameter to display on the right side');
            set(this.visHandles.var_mode_l_pop,'Callback',@this.GUI_varModePop_Callback,'TooltipString','Display one or multiple FLIM parameters on the left side');
            set(this.visHandles.var_mode_r_pop,'Callback',@this.GUI_varModePop_Callback,'TooltipString','Display one or multiple FLIM parameters on the right side');
            set(this.visHandles.dimension_l_pop,'Callback',@this.GUI_dimensionPop_Callback,'TooltipString','Show the whole image in 2D or only the ROI in 2D and 3D respectively on the left side');
            set(this.visHandles.dimension_r_pop,'Callback',@this.GUI_dimensionPop_Callback,'TooltipString','Show the whole image in 2D or only the ROI in 2D and 3D respectively on the right side');
            set(this.visHandles.channel_l_pop,'Callback',@this.GUI_channelPop_Callback,'TooltipString','Switch the spectral channel on the left side');
            set(this.visHandles.channel_r_pop,'Callback',@this.GUI_channelPop_Callback,'TooltipString','Switch the spectral channel on the right side');
            set(this.visHandles.scale_l_pop,'Callback',@this.GUI_scalePop_Callback,'Enable','off','Value',1,'TooltipString','Select linear or log10 scaling of the FLIM parameter on the left side');
            set(this.visHandles.scale_r_pop,'Callback',@this.GUI_scalePop_Callback,'Enable','off','Value',1,'TooltipString','Select linear or log10 scaling of the FLIM parameter on the right side');
            set(this.visHandles.zoom_l_slider,'Callback',@this.GUI_zoom_Callback,'TooltipString','Zoom left side');
            set(this.visHandles.zoom_r_slider,'Callback',@this.GUI_zoom_Callback,'TooltipString','Zoom right side');
            %supp axes
            set(this.visHandles.supp_axes_l_pop,'Callback',@this.GUI_suppAxesPop_Callback,'TooltipString','Show histogram or cross-section for current subject','Value',2);
            set(this.visHandles.supp_axes_r_pop,'Callback',@this.GUI_suppAxesPop_Callback,'TooltipString','Show histogram or cross-section for current subject','Value',2);
            set(this.visHandles.supp_axes_hist_l_pop,'Callback',@this.GUI_suppAxesHistPop_Callback,'TooltipString','Show histogram for current subject or current study / condition');
            set(this.visHandles.supp_axes_hist_r_pop,'Callback',@this.GUI_suppAxesHistPop_Callback,'TooltipString','Show histogram for current subject or current study / condition');
            set(this.visHandles.supp_axes_scale_l_pop,'Callback',@this.GUI_suppAxesScalePop_Callback,'TooltipString','Select linear or log10 scaling for cross-section');
            set(this.visHandles.supp_axes_scale_r_pop,'Callback',@this.GUI_suppAxesScalePop_Callback,'TooltipString','Select linear or log10 scaling for cross-section');
            %cross-sections
            set(this.visHandles.cut_x_l_check,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Enable or disable the vertical cross-section');
            set(this.visHandles.cut_y_l_check,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Enable or disable the horizontal cross-section');
            set(this.visHandles.cut_y_l_slider,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Move horizontal cross-section');
            set(this.visHandles.cut_x_l_slider,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Move vertical cross-section');
            set(this.visHandles.cut_y_l_edit,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Enter position in pixels for horizontal cross-section');
            set(this.visHandles.cut_x_l_edit,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Enter position in pixels for vertical cross-section');
            set(this.visHandles.cut_x_inv_check,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Toggle which side of the cross-section is cut off (3D plot only)');
            set(this.visHandles.cut_y_inv_check,'Callback',@this.GUI_crossSection_Callback,'TooltipString','Toggle which side of the cross-section is cut off (3D plot only)');
            %ROI controls and z scaling
            dims =['x','y','z'];
            axs = ['l','r'];
            for j = 1:2
                ax = axs(j);
                for i=1:3
                    dim = dims(i);
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_dec_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Decrease %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_inc_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Increase %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_edit',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Enter %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_u_dec_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Decrease %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_u_inc_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Increase %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_u_edit',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Enter %s-value',dim));
                end
                set(this.visHandles.(sprintf('ms_%s_z_check',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Enable or disable z scaling');
                set(this.visHandles.(sprintf('roi_type_%s_popup',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Select ROI type');
                set(this.visHandles.(sprintf('roi_subtype_%s_popup',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Select subfield of ETDRS grid');
                set(this.visHandles.(sprintf('roi_vicinity_%s_popup',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Select ''inside'' for the area insode the ROI coordinates, ''invert'' to exclude the ROI area from further analysis or ''vicinity'' to use the area surrounding the ROI');
                set(this.visHandles.(sprintf('roi_%s_table',ax)),'CellEditCallback',@this.GUI_roi_Callback);
                set(this.visHandles.(sprintf('roi_table_clearLast_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Clear last node of current polygon ROI');
                set(this.visHandles.(sprintf('roi_table_clearAll_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Clear all nodes of current polygon ROI');
                set(this.visHandles.(sprintf('roi_add_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Add new ROI');
                set(this.visHandles.(sprintf('roi_delete_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Delete / clear ROI');
                set(this.visHandles.(sprintf('roi_group_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Manage ROI groups');
                set(this.visHandles.(sprintf('roi_apply_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Apply current ROI definition to all subjects in study condition');
                %color scaling controls
                set(this.visHandles.(sprintf('colormap_auto_%s_check',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Enable or disable automatic color scaling');
                set(this.visHandles.(sprintf('colormap_low_%s_edit',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Enter lower border for color scaling');
                set(this.visHandles.(sprintf('colormap_high_%s_edit',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Enter upper border for color scaling');
                set(this.visHandles.(sprintf('colormap_zoom_in_%s_button',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Zoom into histogram',...
                    'String',sprintf('<html><img src="file:/%s" height="16" width="16"></html>',which('FLIMX_zoom_in.png')));
                set(this.visHandles.(sprintf('colormap_zoom_out_%s_button',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Zoom out of histogram',...
                    'String',sprintf('<html><img src="file:/%s" height="14" width="14"></html>',which('FLIMX_zoom_out.png')));
                set(this.visHandles.(sprintf('colormap_misc_%s_button',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Apply current color scaling to all subjects in study condition')
            end
            %menu
            set(this.visHandles.FLIMXVisGUIFigure,'CloseRequestFcn',@this.menuExit_Callback);
            set(this.visHandles.menuFilterOptions,'Callback',@this.menuFiltOpt_Callback);
            set(this.visHandles.menuStatisticsOptions,'Callback',@this.menuStatOpt_Callback);
            set(this.visHandles.menuVisualzationOptions,'Callback',@this.menuVisOpt_Callback);
            set(this.visHandles.menuExportOptions,'Callback',@this.menuExpOpt_Callback);
            set(this.visHandles.menuDescriptive,'Callback',@this.menuDescriptive_Callback);
            set(this.visHandles.menuHolmWilcoxon,'Callback',@this.menuHolmWilcoxon_Callback);
            set(this.visHandles.menuClustering,'Callback',@this.menuClustering_Callback);
            set(this.visHandles.menuOpenStudyMgr,'Callback',@this.menuOpenStudyMgr_Callback);
            set(this.visHandles.menuExportFigureTL,'Callback',@this.menuExportFigure_Callback);
            set(this.visHandles.menuExportFigureTR,'Callback',@this.menuExportFigure_Callback);
            set(this.visHandles.menuExportFigureBL,'Callback',@this.menuExportFigure_Callback);
            set(this.visHandles.menuExportFigureBR,'Callback',@this.menuExportFigure_Callback);
            set(this.visHandles.menuExportAnimationTL,'Callback',@this.menuExportAnimation_Callback);
            set(this.visHandles.menuExportAnimationTR,'Callback',@this.menuExportAnimation_Callback);
            set(this.visHandles.menuExportAnimationBL,'Callback',@this.menuExportAnimation_Callback);
            set(this.visHandles.menuExportAnimationBR,'Callback',@this.menuExportAnimation_Callback);
            set(this.visHandles.menuExportMovie,'Callback',@this.menuExportMovie_Callback);
            set(this.visHandles.menuExportExcelTL,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuExportExcelTR,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuExportExcelBL,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuExportExcelBR,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuOpenFLIMXFit,'Callback',@this.menuOpenFLIMXFit_Callback);
            set(this.visHandles.menuAbout,'Callback',@this.menuAbout_Callback);
            set(this.visHandles.menuUserGuide,'Callback',@this.menuUserGuide_Callback);
            set(this.visHandles.menuWebsite,'Callback',@this.menuWebsite_Callback);
            %intensity overlay
            set(this.visHandles.IO_l_check,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enable or disable overlay of the intensity image on the left side');
            set(this.visHandles.IO_r_check,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enable or disable overlay of the intensity image on the right side');
            set(this.visHandles.IO_l_dec_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Decrease brightness of intensity overlay on the left side');
            set(this.visHandles.IO_r_dec_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Decrease brightness of intensity overlay on the right side');
            set(this.visHandles.IO_l_inc_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Increase brightness of intensity overlay on the left side');
            set(this.visHandles.IO_r_inc_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Increase brightness of intensity overlay on the right side');
            set(this.visHandles.IO_l_edit,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enter brightness value for the intensity overlay on the left side (0: dark; 1: bright)');
            set(this.visHandles.IO_r_edit,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enter brightness value for the intensity overlay on the right side (0: dark; 1: bright)');
            %setup study controls
            set(this.visHandles.study_l_pop,'Callback',@this.GUI_studySet_Callback,'TooltipString','Select current study for the left side');
            set(this.visHandles.study_r_pop,'Callback',@this.GUI_studySet_Callback,'TooltipString','Select current study for the right side');
            set(this.visHandles.view_l_pop,'String',FDTree.defaultConditionName(),'Callback',@this.GUI_conditionSet_Callback,'TooltipString','Select current condition for the current study on left side');
            set(this.visHandles.view_r_pop,'String',FDTree.defaultConditionName(),'Callback',@this.GUI_conditionSet_Callback,'TooltipString','Select current condition for the current study on right side');
            %study color selection
            set(this.visHandles.study_color_l_button,'Callback',@this.GUI_conditionColorSelection_Callback,'TooltipString','Set color for current condition on the left side (only for scatter plots)');
            set(this.visHandles.study_color_r_button,'Callback',@this.GUI_conditionColorSelection_Callback,'TooltipString','Set color for current condition on the right side (only for scatter plots)');
            %progress bars
            set(this.visHandles.cancel_button,'Callback',@this.GUI_cancelButton_Callback,'TooltipString','Stop current operation');
            xpatch = [0 0 0 0];
            ypatch = [0 0 1 1];
            axis(this.visHandles.short_progress_axes ,'off');
            xlim(this.visHandles.short_progress_axes,[0 100]);
            ylim(this.visHandles.short_progress_axes,[0 1]);
            this.visHandles.patch_short_progress = patch(xpatch,ypatch,'m','EdgeColor','m','Parent',this.visHandles.short_progress_axes);%,'EraseMode','normal'
            this.visHandles.text_short_progress = text(1,0,'','Parent',this.visHandles.short_progress_axes);
            axis(this.visHandles.long_progress_axes ,'off');
            xlim(this.visHandles.long_progress_axes,[0 100]);
            ylim(this.visHandles.long_progress_axes,[0 1]);
            this.visHandles.patch_long_progress = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.long_progress_axes);%,'EraseMode','normal'
            this.visHandles.text_long_progress = text(1,0,'','Parent',this.visHandles.long_progress_axes);
            %init ui control objects
            this.objHandles.ldo = FDisplay(this,'l');
            this.objHandles.rdo = FDisplay(this,'r');
            this.objHandles.crossSectionx = CutCtrl(this,'x',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.crossSectiony = CutCtrl(this,'y',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.lROI = ROICtrl(this,'l',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.rROI = ROICtrl(this,'r',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.lZScale = ZCtrl(this,'l',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.rZScale = ZCtrl(this,'r',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.AI = AICtrl(this); %arithmetic image
            this.objHandles.movObj = exportMovie(this);
            this.clearAxes([]);
            this.setupPopUps([]);
            this.visHandles.hrotate3d = rotate3d(this.visHandles.FLIMXVisGUIFigure);
            set(this.visHandles.hrotate3d,'Enable','on','ActionPostCallback',{@FLIMXVisGUI.rotate_postCallback,this});
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.main_l_axes,false);
            this.setupGUI();
            this.updateGUI([]);
            this.objHandles.ldo.drawCPMain([]);
            this.objHandles.rdo.drawCPMain([]);
            this.objHandles.lZScale.updateGUI([]);
            this.objHandles.rZScale.updateGUI([]);
            this.objHandles.ROIGM = []; %ROI group manager
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            %enable mouse button callbacks although 3d rotation is enabled
            %thanks to http://undocumentedmatlab.com/blog/enabling-user-callbacks-during-zoom-pan
            hManager = uigetmodemanager(this.visHandles.FLIMXVisGUIFigure);
            try
                set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
            catch
                [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
            end
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonDownFcn',{@FLIMXVisGUI.rotate_mouseButtonDownWrapper,this});
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonUpFcn',{@FLIMXVisGUI.rotate_mouseButtonUpWrapper,this});
            set(this.visHandles.FLIMXVisGUIFigure,'WindowScrollWheelFcn',@this.GUI_mouseScrollWheel_Callback);
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.short_progress_axes,false);
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.long_progress_axes,false);
        end
        
        function makeDynParams(this)
            %make dynamic (visulaization) parameters
            cm = FLIMX.getColormap(this.generalParams.cmType);%eval(sprintf('%s(256)',lower(this.generalParams.cmType)));
            if(~isempty(cm) && any(cm(:)))
                this.dynParams.cm = cm;
                this.dynParams.cmType = this.generalParams.cmType;
            else
                this.dynParams.cm = jet(256);
                this.dynParams.cmType = 'jet';
            end
            if(this.generalParams.cmInvert)
                this.dynParams.cm = flipud(this.dynParams.cm);
            end
            cm = FLIMX.getColormap(this.generalParams.cmIntensityType);%eval(sprintf('%s(256)',lower(this.generalParams.cmIntensityType)));
            if(~isempty(cm) && any(cm(:)))
                this.dynParams.cmIntensity = cm;
                this.dynParams.cmIntensityType = this.generalParams.cmType;
            else
                this.dynParams.cmIntensity = gray(256);
                this.dynParams.cmIntensityType = 'gray';
            end
            if(this.generalParams.cmIntensityInvert)
                this.dynParams.cmIntensity = flipud(this.dynParams.cmIntensity);
            end
        end
    end %methods protected
    
    methods(Static)
        function [dType, dTypeNr] = FLIMItem2TypeAndID(dType)
            %convert FLIMItem 'Amplitude 1' to 'Amplitude' and 1
            dType = deblank(char(dType));
            %find whitespace
            idx = isstrprop(dType, 'wspace');
            if(any(idx))
                idx = find(idx,1,'last');
                dTypeNr = str2double(dType(idx:end));
                dType = {dType(1:idx-1)};
            else
                dTypeNr = 0;
                dType = {dType};
            end
        end
        
        function rotate_mouseButtonDownWrapper(hObject, eventdata, hFLIMXVis)
            %wrapper for mouse button down funtion in rotate3d mode
            hFLIMXVis.GUI_mouseButtonDown_Callback(hObject, eventdata);
            %now run hrotate3d callback
            %rdata = getuimode(hFig,'Exploration.Rotate3d');
            hManager = uigetmodemanager(hObject);
            try
                hManager.CurrentMode.WindowButtonDownFcn(hObject,eventdata);
            catch
                return
            end
            %hrotate3d callback set the button up function to empty
            try
                set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
            catch
                [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
            end
            set(hObject,'WindowButtonUpFcn',{@FLIMXVisGUI.rotate_mouseButtonUpWrapper,hFLIMXVis});
        end
        
        function rotate_mouseButtonUpWrapper(hObject, eventdata, hFLIMXVis)
            %wrapper for mouse button up funtion in rotate3d mode
            hFLIMXVis.dynParams.mouseButtonIsLeft = true;
            hFLIMXVis.GUI_mouseButtonUp_Callback(hObject, eventdata);
            hFLIMXVis.dynParams.mouseButtonIsLeft = false;
            %in case of 3d roation, we have to call the button up function to stop rotating
            hManager = uigetmodemanager(hObject);
            if(~isempty(hManager.CurrentMode.WindowButtonUpFcn))
                hManager.CurrentMode.WindowButtonUpFcn(hObject,eventdata);
            end
        end
        
        function rotate_postCallback(hObject, eventdata, hFLIMXVis)
            %after rotation we may have to update the axis labels
            if(eventdata.Axes == hFLIMXVis.visHandles.main_l_axes)
                side = 'l';
                otherSide = 'r';
            else
                side = 'r';
                otherSide = 'l';
            end
            hFLIMXVis.objHandles.(sprintf('%sdo',side)).setDispView(get(eventdata.Axes,'View'));
            if(get(hFLIMXVis.visHandles.sync3DViews_check,'Value'))
                hFLIMXVis.objHandles.(sprintf('%sdo',otherSide)).setDispView(get(eventdata.Axes,'View'));
                hFLIMXVis.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
            end
        end
        
        function out = getROIBorderPointerTypes()
            %return possible mouse pointer types when on border of a ROI
            out = {'right','topr','top','topl','left','botl','bottom','botr','crosshair'};
        end
    end  %methods(Static)  
end %classdef