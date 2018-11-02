classdef PART < lsdyna.keyword.card
    %lsdyna.keyword.PART
    
    properties (Constant)
        KeywordMatch = "PART";
    end
    properties (Constant, Hidden)
        DependentCards = ["MAT" "SECTION"]
    end
    
    properties
        Heading(1,1) string = ""
        PID (1,1) double = nan
        MID (1,1) double = nan
        SID (1,1) double = nan
    end
    
    %% CONSTRUCTOR
    methods
        function newCard = PART(basicCard)
            % Allow empty constructor
            if ~nargin
                return;
            end
            % Elseif isa basicCard then convert
            newCard = basicCard.assignPropsToSubclass(newCard);
            % Else call superclass constructor on varargin
        end
        
        function C = arr_stringToData(C)
            % Parse the string data and populate this card's numeric data
            
            % Make sure we're only looking at cards of this type
            targetClass = meta.class.fromName(mfilename('class'));
            if metaclass(C)~=targetClass
                tf = arrayfun(@(x)metaclass(x) <= targetClass, C);
                C = C(tf);
            end
            
            activeStrs = {C.ActiveString};
            % The heading will always be the first line
            headings = cellstr(deblank(cellfun(@(x)x(1),activeStrs)));
            [C.Heading] = headings{:};
            
            % PID, MID, SID are all in the second line
            line2s = cellfun(@(x)x(2),activeStrs(:));
            PIDs = num2cell(double(extractBefore(line2s,11)));
            [C.PID] = PIDs{:};
            MIDs = num2cell(double(extractBetween(line2s,11, 20)));
            [C.MID] = MIDs{:};
            SIDs = num2cell(double(extractBetween(line2s,21, 30)));
            [C.SID] = SIDs{:};
        end
    end
end