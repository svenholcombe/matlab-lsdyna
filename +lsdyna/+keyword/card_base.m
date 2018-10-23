classdef card_base < handle & matlab.mixin.Heterogeneous
    %UNTITLED Summary of this class goes here
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
        function C = parseAllData(C)
            % Make sure we're only looking at cards of this type
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
                C(mask) = C(mask).parseData;
                fprintf("done in %0.2fs.\n",toc)
            end
            
        end
    end
end

