classdef card_base < handle & matlab.mixin.Heterogeneous
    % lsdyna.keyword.card_base is the parent class for all keyword cards.
    % It is a heterogeneous class allowing different card classes to be
    % arrayed together. It defines all methods that can be invoked on an
    % ARRAY of unlike cards. Typically, those methods do one of two things:
    %  1. Iterate through each individual card and invoke a scalar method
    %   for that card. For example, a C.printData() method that acts on an
    %   array of different cards C will invoke the C(i).sca_printData() on
    %   each ith scalar element of C. The sca_printData() method must
    %   therefore be defined in all subclasses.
    %  2. Iterate through each class type and invoke the array method for
    %   all elements sharing a common class. The
    %   Detailed explanation goes here
    
    properties
        Keyword(1,1) string = ""
        String(:,1) string = ""
        File(1,1) lsdyna.keyword.file
        LineNumber(1,1) uint32
    end
    
    properties (Dependent = true)
        ActiveString
    end
    methods
        function X = get.ActiveString(C)
            X = C.String(~startsWith(C.String,"$"));
        end
    end
    
    %% CONSTRUCTOR UTILITY methods
    
    methods
        function newCards = makeSpecificCards(oldCards)
            % Generate specifically defined keyword cards from generic ones
            
            % All specific keyword cards inherit from lsdyna.keyword.card
            supCardClass = ?lsdyna.keyword.card;
            % List the *potential* classes to further specify oldCards as
            allPackageClasses = supCardClass.ContainingPackage.ClassList;
            specificClasses = allPackageClasses(allPackageClasses < supCardClass);
            
            % Copy cards, replace any whos keyword matches a sub-card
            newCards = oldCards;
            oldKeywords = [oldCards.Keyword];
            for sc = 1:length(specificClasses)
                % Make a temporary empty object of the target class
                specClass = specificClasses(sc);
                specClassFcn = str2func(specClass.Name);
                specClassObj = specClassFcn();
                % Use the KeywordMatch property to find matching cards
                matchInds = find(startsWith(oldKeywords,specClassObj.KeywordMatch));
                for i = 1:length(matchInds)
                    tmp = specClassFcn(oldCards(matchInds(i)));
                    newCards(matchInds(i)) = tmp;
                end
            end
        end
    end
    
    %% PARSER UTILITY methods

    methods (Sealed)
        function strsCell = dataToString(C)
            % Requires "sca_dataToString()" to be defined in all subclasses
            nC = numel(C);
            strsCell = cell(nC,1);
            for i = 1:nC
                strsCell{i} = sca_dataToString(C(i));
            end
        end
        function C = stringToData(C)
            % Requires "arr_stringToData()" to be defined in all subclasses

            % Find all subclasses of lsdyna.keyword.card in C and invoke
            % their arr_stringToData method.
            supCardClass = ?lsdyna.keyword.card;
            [unqClasses,~,classGrps] = unique(arrayfun(@class, C, 'Un', 0));
            for grp = 1:length(unqClasses)
                className = unqClasses{grp};
                if isequal(className,supCardClass.Name)
                    % Nothing to parse for basic unspecified cards
                    continue;
                end
                mask = classGrps==grp;
                fprintf("Parsing %s cards [%d] ... ",className,nnz(mask))
                tic
                C(mask) = C(mask).arr_stringToData;
                fprintf("done in %0.2fs.\n",toc)
            end
        end
    end
end

