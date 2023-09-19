classdef sliceViewerApp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        sliceViewerAppv110Label  matlab.ui.control.Label
        ImagePanel               matlab.ui.container.Panel
        ResetboundsButton        matlab.ui.control.Button
        TitleCheckBox            matlab.ui.control.CheckBox
        ColorbarCheckBox         matlab.ui.control.CheckBox
        MinVisRange              matlab.ui.control.NumericEditField
        MinEditFieldLabel        matlab.ui.control.Label
        MaxVisRange              matlab.ui.control.NumericEditField
        MaxEditFieldLabel        matlab.ui.control.Label
        ColormapDropDown         matlab.ui.control.DropDown
        SliceoptionButtonGroup   matlab.ui.container.ButtonGroup
        DLamp                    matlab.ui.control.Lamp
        DLampLabel               matlab.ui.control.Label
        TransposeCheckBox        matlab.ui.control.CheckBox
        ZTplaneButton            matlab.ui.control.RadioButton
        XTplaneButton            matlab.ui.control.RadioButton
        YTplaneButton            matlab.ui.control.RadioButton
        YZplaneButton            matlab.ui.control.RadioButton
        XZplaneButton            matlab.ui.control.RadioButton
        XYplaneButton            matlab.ui.control.RadioButton
        TimeButtonAmount         matlab.ui.control.Spinner
        SliceButtonAmount        matlab.ui.control.Spinner
        TimeMinusManyButton      matlab.ui.control.Button
        SliceMinusManyButton     matlab.ui.control.Button
        TimePlusManyButton       matlab.ui.control.Button
        SlicePlusManyButton      matlab.ui.control.Button
        TimeMinusOneButton       matlab.ui.control.Button
        SliceMinusOneButton      matlab.ui.control.Button
        TimePlusOneButton        matlab.ui.control.Button
        SlicePlusOneButton       matlab.ui.control.Button
        ExportimagePanel         matlab.ui.container.Panel
        GridLayout               matlab.ui.container.GridLayout
        FormatDropDown           matlab.ui.control.DropDown
        FilenameEditField        matlab.ui.control.EditField
        SaveButton               matlab.ui.control.Button
        TimestepSlider           matlab.ui.control.Slider
        TimestepLabel            matlab.ui.control.Label
        SliceSlider              matlab.ui.control.Slider
        SliceSliderLabel         matlab.ui.control.Label
        imgElement               matlab.ui.control.UIAxes
    end

    
    %% sliceViewerApp %%
    % Matlab app for viewing 2D slices (images) from 3D and 4D volumes
    % easily. Allows some tuning of the data and easy saving of images.
    %
    % Tommi Heikkilä
    % Created 26.4.2021
    % Last changed 19.9.2023

    properties (Access = public)
        % Here are all of the variables which can be accessed by the app
        % (and also from outside the app).
        
        V % Volume we wish to view
        Vsize % Size of the volume
        
        is4D % Boolean for 4D arrays
        
        % Min and max value for meaningful normalization of images
        Vmax; % Max value of V
        Vmin; % Min value of V
        Irange; % Visualized color range, default: [Vmax Vmin]
        
        zoom; % Image magnification, default: 0 = 'fit' (not implemented!)
        
        perm; % Orientation of V
        prevPlane; % Previous orientation
        
        cmap; % Current colormap for the image
        cmIn; % User given input colormap
        
        imName; % Image name with running numbering
        imNum; % Current number of image
    end
    
    methods (Access = private)
        
        function app = updImg(app) % Update appearance/orientation of image
            % Temporary volume V
            Vtmp = permute(app.V,app.perm);

            % Choose one slice from permuted volume
            I = Vtmp(:,:,app.SliceSlider.Value,app.TimestepSlider.Value);
            if app.TransposeCheckBox.Value
                % Switch rows and columns if checked
                I = I';
            end
            % Show correct slice
            % Parent sets the image under the imgElement! This is important!
            imshow(I',app.Irange,'InitialMagnification',app.zoom,...
                'Parent',app.imgElement)
            
            updColormap(app); % Colormap might change
            updTitle(app); % Title might change
        end
        %%%%%
        function app = updSliceSliderLim(app) % Update slider limits etc. (3rd dimension)
            % Tune slider parameters
            Vpersize = app.Vsize(app.perm); % Changing orientation can change the max size of different directions
            if Vpersize(3) < app.SliceSlider.Value % Reset if slice is out of bounds
                app.SliceSlider.Value = 1;
            end
            app.SliceSlider.Limits = [1 Vpersize(3)];
            % Use custom function to define nice ticks
            [Mt, mt] = sickTicks(app,Vpersize(3));
            app.SliceSlider.MajorTicks = Mt;
            app.SliceSlider.MinorTicks = mt;
        end
        %%%%%
        function app = updTimeSliderLim(app) % Update slider limits etc. (4th dimension)
            % Tune time step slider
            Vpersize = app.Vsize(app.perm); % Changing orientation can change the max size of different directions
            if Vpersize(4) < app.TimestepSlider.Value % Reset if time step is out of bounds
                app.TimestepSlider.Value = 1;
            end
            app.TimestepSlider.Limits = [1 max(Vpersize(4),1.1)];
            % Use custom function to define nice ticks
            [Mt, mt] = sickTicks(app,Vpersize(4));
            app.TimestepSlider.MajorTicks = Mt;
            app.TimestepSlider.MinorTicks = mt;
        end
        %%%%%
        function updTitle(app) % Update image title
            % Show which slice
            titletext = ['Slice = ',num2str(app.SliceSlider.Value)];
            % Show which time step (in 4D only)
            if app.is4D
                titletext = [titletext, ' t = ',num2str(app.TimestepSlider.Value)];
            end
            
            % Set image title if user wants it
            if app.TitleCheckBox.Value
                % Note that the title is a property of the imgElement
                title(app.imgElement, titletext);
            else
                title(app.imgElement, []);
            end
        end
        %%%%%
        function updColormap(app) % Update the colormap
            % Colormap is a property of the imgElement
            colormap(app.imgElement,app.cmap); % Update
        end
        %%%%%
        function filenameCheck(app,fNum) % Check the format of the filename and case the number to it if needed
            if nargin == 2 % fNum is optional
                app.imNum = fNum;
            end
            % Field content
            value = app.FilenameEditField.Value;
            % Last 3 characters should be a number (in %03d format)
            n = str2double((value(end-2:end)));
            % Check that we have a whole number (str2double(char) = NaN)
            if isnumeric(n) && rem(n,1) == 0 && ~isnan(n)
                app.imName = value(1:end-3);
                if nargin < 2 % If fNum is not forced, use whatever was there
                    app.imNum = n;
                end
            else % If not a number
                app.imName = value;
                if nargin < 2 % If fNum is not forced, use 1
                    app.imNum = 1;
                end
            end
            % Updates the visible text field to include current number
            app.FilenameEditField.Value = sprintf([app.imName,'%03d'],app.imNum);
        end
        %%%%%
        function updSliderWithButton(app,slider,amount)
            switch slider
                case 'slice'
                    % Update sliceSlider by amount
                    newValue = app.SliceSlider.Value + amount;
                    % Slider limits
                    L = app.SliceSlider.Limits;
                    % Change slider value within limits
                    app.SliceSlider.Value = fix(min(L(2),max(L(1),newValue)));
                    % Update image
                    updImg(app);
                    
                case 'time'
                    % Update timeSlider by 'amount'
                    newValue = app.TimestepSlider.Value + amount;
                    % Slider limits
                    L = app.TimestepSlider.Limits;
                    % Change slider value within limits
                    app.TimestepSlider.Value = fix(min(L(2),max(L(1),newValue)));
                    % Update image
                    updImg(app);
            end
        end
    end
    
  methods (Access = public)
            
        function [Mtick,mtick] = sickTicks(app,N)
        % Create major and minor ticks for 1:N
        
        % Default to no minor tick
        mtick = []; %
        % Special case
        if N == 1
            Mtick = 1; % Major tick
            return
        end
        % We want about 10 major ticks
        Mjump = max(1,floor(N/10));
        Mtick = [1, 1+Mjump:Mjump:N-min(Mjump,2), N];
        % Fill missing spots with minor ticks
        if Mjump > 1
            mtick = 1:N;
        end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, V, cm)
            app.V = V;
            if nargin < 3
                cm = 'default'; % Default colormap is 'parula' atm.
            end
            app.cmIn = cm; % User input colormap
            
            app.Vsize = size(V); % Size of V
            
            if length(app.Vsize) == 4 % Is a 4D array
                app.is4D = true;
                app.DLamp.Enable = 'on'; % Cool lamp
            else
                app.is4D = false; % Not a 4D array
                app.DLamp.Enable = 'off';
                app.Vsize(4) = 1; % We want Vsize to be of length 4
            end
            
            % Image range
            app.Vmax = max(V(:)); % Max value of whole V
            app.Vmin = min(V(:)); % Minimum value of whole V
            app.Irange = [app.Vmin app.Vmax]; % Default range
            app.MaxVisRange.Value = double(app.Vmax);
            app.MinVisRange.Value = double(app.Vmin);

            % Image magnification
            app.zoom = 'fit';
            
            % Orientation array
            app.perm = [1 2 3 4];
            % Previous orientation
            app.prevPlane = app.SliceoptionButtonGroup.SelectedObject;
            
            % Default slice
            app = updSliceSliderLim(app);
            
            % Default time
            app = updTimeSliderLim(app);
            
            % Default colormap
            app.cmap = 'gray';
            % Change the last value to actual colormap instead of char
            % because we can not load 'app.cmIn'
            app.ColormapDropDown.ItemsData{end} = app.cmIn;
            
            % Initialize with the update function
            updImg(app);
            updColormap(app);
            colorbar(app.imgElement); % Enable colorbar by default
            
            % Image saving variables for name and number
            app.imName = app.FilenameEditField.Value;
            app.imNum = 1;
            app.FilenameEditField.Value = sprintf([app.imName,'%03d'],app.imNum);
            
        end

        % Value changed function: SliceSlider
        function SliceSliderValueChanged(app, event)
            % Slider rounds its own value to integer and updates image
            app.SliceSlider.Value = round(app.SliceSlider.Value);
            updImg(app);
        end

        % Selection changed function: SliceoptionButtonGroup
        function SliceoptionButtonGroupSelectionChanged(app, event)
            % This changes the orientation of the volume.
            % Last 3 options are sort of nonsensical but useful
            selectedButton = app.SliceoptionButtonGroup.SelectedObject;
            switch selectedButton
                % Image always visualizes the first two dimensions
                case app.XYplaneButton
                    app.perm = [1 2 3 4];
                case app.XZplaneButton
                    app.perm = [1 3 2 4];
                case app.YZplaneButton
                    app.perm = [2 3 1 4];
                    
                % These are for 4D only!
                case app.YTplaneButton
                    if app.is4D
                        app.perm = [2 4 3 1];
                    else
                        % Reset if 3D
                        app.SliceoptionButtonGroup.SelectedObject = app.prevPlane;
                        return
                    end
                case app.XTplaneButton
                    if app.is4D
                        app.perm = [1 4 3 2];
                    else
                        % Reset if 3D
                        app.SliceoptionButtonGroup.SelectedObject = app.prevPlane;
                        return
                    end
                case app.ZTplaneButton
                    if app.is4D
                        app.perm = [3 4 1 2];
                    else
                        % Reset if 3D
                        app.SliceoptionButtonGroup.SelectedObject = app.prevPlane;
                        return
                    end
            end
            % Update previous orientation
            app.prevPlane = app.SliceoptionButtonGroup.SelectedObject;
            % Update sliders
            app = updSliceSliderLim(app);
            if app.is4D
                app = updTimeSliderLim(app);
            end
            % Update image
            updImg(app);
        end

        % Value changed function: ColormapDropDown
        function ColormapDropDownValueChanged(app, event)
            app.cmap = app.ColormapDropDown.Value;
            % Update the colormap
            updColormap(app);
        end

        % Value changed function: TimestepSlider
        function TimestepSliderValueChanged(app, event)
            % Slider rounds its own value to integer and updates image
            app.TimestepSlider.Value = round(app.TimestepSlider.Value);
            updImg(app);
        end

        % Value changed function: ColorbarCheckBox
        function ColorbarCheckBoxValueChanged(app, event)
            % Colorbar is a property of imgElement
            if app.ColorbarCheckBox.Value
                colorbar(app.imgElement); % Enable colorbar
            else
                colorbar(app.imgElement,'off') % Disable colorbar
            end
        end

        % Value changed function: TitleCheckBox
        function TitleCheckBoxValueChanged(app, event)
            % Is this good programming?
            updTitle(app);
        end

        % Button pushed function: SaveButton
        function SaveButtonPushed(app, event)
            % Save using flName and flType filetype
            flName = app.FilenameEditField.Value;
            flType = app.FormatDropDown.Value;
            % Have to use exportgraphics with imgElement instead of print!
            % Matlab is weird
            exportgraphics(app.imgElement,[flName,flType]);
            % Check filename and force number to be imNum + 1
            filenameCheck(app,app.imNum + 1);
        end

        % Value changed function: FilenameEditField
        function FilenameEditFieldValueChanged(app, event)
            % Change number or add it if user changes filename
            filenameCheck(app);
        end

        % Value changed function: TransposeCheckBox
        function TransposeCheckBoxValueChanged(app, event)
            % Update the image
            updImg(app);
        end

        % Button pushed function: SlicePlusOneButton
        function SlicePlusOneButtonPushed(app, event)
            updSliderWithButton(app,'slice',1);
        end

        % Button pushed function: TimePlusOneButton
        function TimePlusOneButtonPushed(app, event)
            updSliderWithButton(app,'time',1);
        end

        % Button pushed function: SliceMinusOneButton
        function SliceMinusOneButtonPushed(app, event)
            updSliderWithButton(app,'slice',-1);
        end

        % Button pushed function: TimeMinusOneButton
        function TimeMinusOneButtonPushed(app, event)
            updSliderWithButton(app,'time',-1);
        end

        % Button pushed function: SlicePlusManyButton
        function SlicePlusManyButtonPushed(app, event)
            updSliderWithButton(app,'slice',app.SliceButtonAmount.Value);
        end

        % Button pushed function: TimePlusManyButton
        function TimePlusManyButtonPushed(app, event)
            updSliderWithButton(app,'time',app.TimeButtonAmount.Value);
        end

        % Button pushed function: SliceMinusManyButton
        function SliceMinusManyButtonPushed(app, event)
            updSliderWithButton(app,'slice',-app.SliceButtonAmount.Value);
        end

        % Button pushed function: TimeMinusManyButton
        function TimeMinusManyButtonPushed(app, event)
            updSliderWithButton(app,'time',-app.TimeButtonAmount.Value);
        end

        % Value changed function: MaxVisRange
        function MaxVisRangeValueChanged(app, event)
            newMax = app.MaxVisRange.Value;
            if newMax < app.Irange(1) % Must be: max > min
                newMax = app.Irange(1);
                app.MaxVisRange.Value = newMax;
            end
            app.Irange(2) = newMax;
            updImg(app);
        end

        % Value changed function: MinVisRange
        function MinVisRangeValueChanged(app, event)
            newMin = app.MinVisRange.Value;
            if newMin > app.Irange(2) % Must be: min < max
                newMin = app.Irange(2);
                app.MinVisRange.Value = newMin;
            end
            app.Irange(1) = newMin;
            updImg(app);
        end

        % Callback function
        function ZoomEditFieldValueChanged(app, event)
            zoomValue = app.ZoomEditField.Value;
            if zoomValue == 0
                zoomValue = 'fit';
            end
            app.zoom = zoomValue;
            updImg(app);
        end

        % Button pushed function: ResetboundsButton
        function ResetboundsButtonPushed(app, event)
            % Reset VisRangeValues to global min and max
            app.MaxVisRange.Value = double(app.Vmax);
            app.MinVisRange.Value = double(app.Vmin);
            % Update actual range used
            app.Irange = [app.Vmin, app.Vmax];
            % Update image
            updImg(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 672 623];
            app.UIFigure.Name = 'MATLAB App';

            % Create imgElement
            app.imgElement = uiaxes(app.UIFigure);
            title(app.imgElement, 'Slice ')
            app.imgElement.DataAspectRatio = [1 1 1];
            app.imgElement.PlotBoxAspectRatio = [1 1 1];
            app.imgElement.XTickLabelRotation = 0;
            app.imgElement.YTickLabelRotation = 0;
            app.imgElement.ZTickLabelRotation = 0;
            app.imgElement.Position = [13 123 527 491];

            % Create SliceSliderLabel
            app.SliceSliderLabel = uilabel(app.UIFigure);
            app.SliceSliderLabel.Position = [41 102 46 22];
            app.SliceSliderLabel.Text = 'Slice';

            % Create SliceSlider
            app.SliceSlider = uislider(app.UIFigure);
            app.SliceSlider.MajorTicks = 1;
            app.SliceSlider.ValueChangedFcn = createCallbackFcn(app, @SliceSliderValueChanged, true);
            app.SliceSlider.MinorTicks = [];
            app.SliceSlider.Position = [128 111 244 3];
            app.SliceSlider.Value = 1;

            % Create TimestepLabel
            app.TimestepLabel = uilabel(app.UIFigure);
            app.TimestepLabel.Position = [37 35 58 28];
            app.TimestepLabel.Text = 'Time step';

            % Create TimestepSlider
            app.TimestepSlider = uislider(app.UIFigure);
            app.TimestepSlider.Limits = [1 1.1];
            app.TimestepSlider.MajorTicks = 1;
            app.TimestepSlider.ValueChangedFcn = createCallbackFcn(app, @TimestepSliderValueChanged, true);
            app.TimestepSlider.MinorTicks = 1;
            app.TimestepSlider.Position = [128 49 244 3];
            app.TimestepSlider.Value = 1;

            % Create ExportimagePanel
            app.ExportimagePanel = uipanel(app.UIFigure);
            app.ExportimagePanel.Tooltip = {'By default all images are saved into the current folder.'};
            app.ExportimagePanel.Title = 'Export image';
            app.ExportimagePanel.Position = [388 19 274 105];

            % Create GridLayout
            app.GridLayout = uigridlayout(app.ExportimagePanel);

            % Create SaveButton
            app.SaveButton = uibutton(app.GridLayout, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.FontSize = 14;
            app.SaveButton.Layout.Row = [1 2];
            app.SaveButton.Layout.Column = 1;
            app.SaveButton.Text = 'Save';

            % Create FilenameEditField
            app.FilenameEditField = uieditfield(app.GridLayout, 'text');
            app.FilenameEditField.ValueChangedFcn = createCallbackFcn(app, @FilenameEditFieldValueChanged, true);
            app.FilenameEditField.HorizontalAlignment = 'center';
            app.FilenameEditField.Layout.Row = 2;
            app.FilenameEditField.Layout.Column = 2;
            app.FilenameEditField.Value = 'filename';

            % Create FormatDropDown
            app.FormatDropDown = uidropdown(app.GridLayout);
            app.FormatDropDown.Items = {'PNG', 'EPS', 'PDF', 'JPEG'};
            app.FormatDropDown.ItemsData = {'.png', '.eps', '.pdf', '.jpeg'};
            app.FormatDropDown.Layout.Row = 1;
            app.FormatDropDown.Layout.Column = 2;
            app.FormatDropDown.Value = '.png';

            % Create SlicePlusOneButton
            app.SlicePlusOneButton = uibutton(app.UIFigure, 'push');
            app.SlicePlusOneButton.ButtonPushedFcn = createCallbackFcn(app, @SlicePlusOneButtonPushed, true);
            app.SlicePlusOneButton.Tooltip = {'Increase current slice by one.'};
            app.SlicePlusOneButton.Position = [94 102 23 21];
            app.SlicePlusOneButton.Text = '>';

            % Create TimePlusOneButton
            app.TimePlusOneButton = uibutton(app.UIFigure, 'push');
            app.TimePlusOneButton.ButtonPushedFcn = createCallbackFcn(app, @TimePlusOneButtonPushed, true);
            app.TimePlusOneButton.Tooltip = {'Increase current time step by one.'};
            app.TimePlusOneButton.Position = [94 40 23 21];
            app.TimePlusOneButton.Text = '>';

            % Create SliceMinusOneButton
            app.SliceMinusOneButton = uibutton(app.UIFigure, 'push');
            app.SliceMinusOneButton.ButtonPushedFcn = createCallbackFcn(app, @SliceMinusOneButtonPushed, true);
            app.SliceMinusOneButton.Tooltip = {'Decrease current slice by one.'};
            app.SliceMinusOneButton.Position = [9 102 25 22];
            app.SliceMinusOneButton.Text = '<';

            % Create TimeMinusOneButton
            app.TimeMinusOneButton = uibutton(app.UIFigure, 'push');
            app.TimeMinusOneButton.ButtonPushedFcn = createCallbackFcn(app, @TimeMinusOneButtonPushed, true);
            app.TimeMinusOneButton.Tooltip = {'Decrease current time step by one.'};
            app.TimeMinusOneButton.Position = [9 40 25 21];
            app.TimeMinusOneButton.Text = '<';

            % Create SlicePlusManyButton
            app.SlicePlusManyButton = uibutton(app.UIFigure, 'push');
            app.SlicePlusManyButton.ButtonPushedFcn = createCallbackFcn(app, @SlicePlusManyButtonPushed, true);
            app.SlicePlusManyButton.Tooltip = {'Increase current slice by set amount.'};
            app.SlicePlusManyButton.Position = [94 71 23 22];
            app.SlicePlusManyButton.Text = '>>';

            % Create TimePlusManyButton
            app.TimePlusManyButton = uibutton(app.UIFigure, 'push');
            app.TimePlusManyButton.ButtonPushedFcn = createCallbackFcn(app, @TimePlusManyButtonPushed, true);
            app.TimePlusManyButton.Tooltip = {'Increase current time step by set amount.'};
            app.TimePlusManyButton.Position = [94 12 23 22];
            app.TimePlusManyButton.Text = '>>';

            % Create SliceMinusManyButton
            app.SliceMinusManyButton = uibutton(app.UIFigure, 'push');
            app.SliceMinusManyButton.ButtonPushedFcn = createCallbackFcn(app, @SliceMinusManyButtonPushed, true);
            app.SliceMinusManyButton.Tooltip = {'Decrease current slice by set amount.'};
            app.SliceMinusManyButton.Position = [9 72 25 22];
            app.SliceMinusManyButton.Text = '<<';

            % Create TimeMinusManyButton
            app.TimeMinusManyButton = uibutton(app.UIFigure, 'push');
            app.TimeMinusManyButton.ButtonPushedFcn = createCallbackFcn(app, @TimeMinusManyButtonPushed, true);
            app.TimeMinusManyButton.Tooltip = {'Decrease current time step by set amount.'};
            app.TimeMinusManyButton.Position = [9 12 25 22];
            app.TimeMinusManyButton.Text = '<<';

            % Create SliceButtonAmount
            app.SliceButtonAmount = uispinner(app.UIFigure);
            app.SliceButtonAmount.Limits = [1 10];
            app.SliceButtonAmount.Position = [37 71 50 22];
            app.SliceButtonAmount.Value = 2;

            % Create TimeButtonAmount
            app.TimeButtonAmount = uispinner(app.UIFigure);
            app.TimeButtonAmount.Limits = [1 10];
            app.TimeButtonAmount.Position = [37 12 50 22];
            app.TimeButtonAmount.Value = 2;

            % Create SliceoptionButtonGroup
            app.SliceoptionButtonGroup = uibuttongroup(app.UIFigure);
            app.SliceoptionButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @SliceoptionButtonGroupSelectionChanged, true);
            app.SliceoptionButtonGroup.Tooltip = {'Choose which two "dimensions" of the array are visualized.'; ''; 'Visualizing 4th dimension will make the labels nonsensical.'};
            app.SliceoptionButtonGroup.Title = 'Slice option';
            app.SliceoptionButtonGroup.Position = [532 370 130 244];

            % Create XYplaneButton
            app.XYplaneButton = uiradiobutton(app.SliceoptionButtonGroup);
            app.XYplaneButton.Text = 'XY-plane';
            app.XYplaneButton.FontSize = 14;
            app.XYplaneButton.Position = [11 198 78 22];
            app.XYplaneButton.Value = true;

            % Create XZplaneButton
            app.XZplaneButton = uiradiobutton(app.SliceoptionButtonGroup);
            app.XZplaneButton.Text = 'XZ-plane';
            app.XZplaneButton.FontSize = 14;
            app.XZplaneButton.Position = [11 176 79 22];

            % Create YZplaneButton
            app.YZplaneButton = uiradiobutton(app.SliceoptionButtonGroup);
            app.YZplaneButton.Text = 'YZ-plane';
            app.YZplaneButton.FontSize = 14;
            app.YZplaneButton.Position = [11 155 79 22];

            % Create YTplaneButton
            app.YTplaneButton = uiradiobutton(app.SliceoptionButtonGroup);
            app.YTplaneButton.Text = 'YT-plane';
            app.YTplaneButton.FontColor = [0.502 0.502 0.502];
            app.YTplaneButton.Position = [11 32 70 22];

            % Create XTplaneButton
            app.XTplaneButton = uiradiobutton(app.SliceoptionButtonGroup);
            app.XTplaneButton.Text = 'XT-plane';
            app.XTplaneButton.FontColor = [0.502 0.502 0.502];
            app.XTplaneButton.Position = [11 53 70 22];

            % Create ZTplaneButton
            app.ZTplaneButton = uiradiobutton(app.SliceoptionButtonGroup);
            app.ZTplaneButton.Text = 'ZT-plane';
            app.ZTplaneButton.FontColor = [0.502 0.502 0.502];
            app.ZTplaneButton.Position = [11 11 69 22];

            % Create TransposeCheckBox
            app.TransposeCheckBox = uicheckbox(app.SliceoptionButtonGroup);
            app.TransposeCheckBox.ValueChangedFcn = createCallbackFcn(app, @TransposeCheckBoxValueChanged, true);
            app.TransposeCheckBox.Text = 'Transpose';
            app.TransposeCheckBox.Position = [11 130 78 22];

            % Create DLampLabel
            app.DLampLabel = uilabel(app.SliceoptionButtonGroup);
            app.DLampLabel.HorizontalAlignment = 'center';
            app.DLampLabel.Position = [47 90 25 22];
            app.DLampLabel.Text = '4D';

            % Create DLamp
            app.DLamp = uilamp(app.SliceoptionButtonGroup);
            app.DLamp.Position = [19 87 28 28];

            % Create ImagePanel
            app.ImagePanel = uipanel(app.UIFigure);
            app.ImagePanel.Title = 'Image';
            app.ImagePanel.Position = [532 145 130 209];

            % Create ColormapDropDown
            app.ColormapDropDown = uidropdown(app.ImagePanel);
            app.ColormapDropDown.Items = {'gray', 'parula', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter', 'bone', 'copper', 'pink', 'jet', 'custom'};
            app.ColormapDropDown.ItemsData = {'gray', 'parula', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter', 'bone', 'copper', 'pink', 'jet', 'app.cmIn'};
            app.ColormapDropDown.ValueChangedFcn = createCallbackFcn(app, @ColormapDropDownValueChanged, true);
            app.ColormapDropDown.Position = [11 154 110 22];
            app.ColormapDropDown.Value = 'gray';

            % Create MaxEditFieldLabel
            app.MaxEditFieldLabel = uilabel(app.ImagePanel);
            app.MaxEditFieldLabel.Position = [11 121 31 22];
            app.MaxEditFieldLabel.Text = 'Max ';

            % Create MaxVisRange
            app.MaxVisRange = uieditfield(app.ImagePanel, 'numeric');
            app.MaxVisRange.ValueDisplayFormat = '%3.4e';
            app.MaxVisRange.ValueChangedFcn = createCallbackFcn(app, @MaxVisRangeValueChanged, true);
            app.MaxVisRange.Position = [35 118 87 27];

            % Create MinEditFieldLabel
            app.MinEditFieldLabel = uilabel(app.ImagePanel);
            app.MinEditFieldLabel.Position = [11 87 25 22];
            app.MinEditFieldLabel.Text = 'Min';

            % Create MinVisRange
            app.MinVisRange = uieditfield(app.ImagePanel, 'numeric');
            app.MinVisRange.ValueDisplayFormat = '%3.4e';
            app.MinVisRange.ValueChangedFcn = createCallbackFcn(app, @MinVisRangeValueChanged, true);
            app.MinVisRange.Position = [35 84 86 27];

            % Create ColorbarCheckBox
            app.ColorbarCheckBox = uicheckbox(app.ImagePanel);
            app.ColorbarCheckBox.ValueChangedFcn = createCallbackFcn(app, @ColorbarCheckBoxValueChanged, true);
            app.ColorbarCheckBox.Tooltip = {'Show colormap'};
            app.ColorbarCheckBox.Text = 'Colorbar';
            app.ColorbarCheckBox.Position = [54 11 68 22];
            app.ColorbarCheckBox.Value = true;

            % Create TitleCheckBox
            app.TitleCheckBox = uicheckbox(app.ImagePanel);
            app.TitleCheckBox.ValueChangedFcn = createCallbackFcn(app, @TitleCheckBoxValueChanged, true);
            app.TitleCheckBox.Tooltip = {'Show title'};
            app.TitleCheckBox.Text = 'Title';
            app.TitleCheckBox.Position = [11 11 44 22];
            app.TitleCheckBox.Value = true;

            % Create ResetboundsButton
            app.ResetboundsButton = uibutton(app.ImagePanel, 'push');
            app.ResetboundsButton.ButtonPushedFcn = createCallbackFcn(app, @ResetboundsButtonPushed, true);
            app.ResetboundsButton.WordWrap = 'on';
            app.ResetboundsButton.Position = [11 41 51 35];
            app.ResetboundsButton.Text = 'Reset bounds';

            % Create sliceViewerAppv110Label
            app.sliceViewerAppv110Label = uilabel(app.UIFigure);
            app.sliceViewerAppv110Label.HorizontalAlignment = 'right';
            app.sliceViewerAppv110Label.FontSize = 10;
            app.sliceViewerAppv110Label.FontColor = [0.651 0.651 0.651];
            app.sliceViewerAppv110Label.Position = [537 -2 123 22];
            app.sliceViewerAppv110Label.Text = 'sliceViewerApp v1.1.0';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = sliceViewerApp_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end