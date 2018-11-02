classdef file < handle
    %An LS-Dyna keyword file class
    %   Detailed explanation goes here
    
    properties
        Filepath(1,1) string = ""
        Filename(1,1) string = ""
        Preamble(:,1) string = ""
        Cards(:,1) lsdyna.keyword.card_base
    end
    
    %% CONSTRUCTOR
    methods
        function F = file(filename,varargin)
            if ~nargin
                % Make an empty file
                return;
            end
            [F.Filepath,fname,fext] = fileparts(filename);
            F.Filename = [fname fext];
            % Add potential custom input
            IP = inputParser;
            IP.addParameter('Cards',[])
            IP.addParameter('Preamble',"")
            IP.parse(varargin{:})
            givenFields = setdiff(IP.Parameters,IP.UsingDefaults);
            for i = 1:length(givenFields)
                fld = givenFields{i};
                F.(fld) = IP.Results.(fld);
            end
            
        end
        
        function makeSpecificCards(F)
            % "Dive down" from the most generic card definition to apply
            % specific card classes to all cards where available
            F.Cards = makeSpecificCards(F.Cards);
        end
        
    end
    
    
    
    methods (Static)
        function F = readKfile(FILE,firstNlines)
            % readKfile(FILE) % Read the keyword FILE
            % readKfile(STRING) % Read the keywords from the given STRING
            % readKfile(...,NLINES) % Read just NLINES lines (for testing)
            
            % Determine the input syntax and read
            if (isStringScalar(FILE) || ischar(FILE)) ...
                    && strlength(FILE) < 1000 && exist(FILE,'file')
                filename = FILE;
                tic
                fprintf("Reading %s ... ", FILE)
                X = string(fileread(FILE));
                fprintf("read %0.0fK chars in %0.2fs.\n", strlength(X)/1000, toc)
            else
                filename = 'Untitled.k';
                X = string(FILE);
            end
            
            % Split into individual lines
            if isscalar(X)
                fprintf("Splitting contents ... ")
                tic
                X = splitlines(X);
                fprintf("found %d lines in %0.2fs.\n", numel(X), toc)
            end            
            
            % Determine where keywords begin
            fprintf("Reading keywords ... ")
            tic
            if nargin<2
                firstNlines = length(X);
            end
            tmp = X(1:firstNlines);
            keywordLineNos = find(startsWith(tmp,'*'));
            fprintf("%d read in %0.2fs\n", numel(keywordLineNos), toc)
            
            % Collect keyword strings and card contents strings
            fprintf("Building keywords list ... ")
            tic
            preComments = tmp(1:keywordLineNos(1)-1);
            keywords = strip(deblank(tmp(keywordLineNos)), 'left',"*");
            cardsStart = keywordLineNos + 1;
            cardsEnd = [keywordLineNos(2:end)-1; length(tmp)];
            cardsCell = arrayfun(@(from,to)tmp(from:to),cardsStart,cardsEnd,'Un',0);
            fprintf(" done in %0.2fs\n", toc)
            
            % Build the card objects
            fprintf("Building basic cards ... ")
            tic
            cards = lsdyna.keyword.card(keywords,cardsCell);
            fprintf("done in %0.2fs\n", toc)
            
            % Build the kfile object and populate it
            F = lsdyna.keyword.file(filename,'Cards',cards,'Preamble',preComments);
            % It's quickest to assign all cards a line number at once
            lineNos = num2cell(uint32(cardsStart));
            [F.Cards.LineNumber] = lineNos{:};
            [F.Cards.File] = deal(F);
            
            fprintf("Building specific cards ... ")
            tic
            F.makeSpecificCards;
            fprintf("done in %0.2fs\n", toc)
            
            F.Cards.stringToData;
            
        end
    end
end

