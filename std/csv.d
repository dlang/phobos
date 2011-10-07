module csv;

private import std.stdio    : write, File, exists, StdioException, lines;
private import std.stream   : BufferedFile;
private import std.string   : string, format, stripRight, stripLeft;
private import std.array    : split, join;
private import std.exception: Exception;
private import std.math     : abs, fmax, fmin;
/**
 * parse file separated by a separator like ','. By default ',' is the separator it could be change by any string.
 * In more if your file have some comment line you can said how detect comment line by set var comment. In last
 * Some format conatins metadata, and a metadaline could be detect because this line start always by an identifier. So
 * if you format have a metadata line set metadaLine variable.
 * This function do not cost many memory. Each line are generated at each iteration.
 *
 * Examples:
 * --------------------
 *
 * import csv;
 * CSV myData1 = open("path/to/file.csv");
 * CSV myData2 = open("path/to/file.tsv", "\t");
 * CSV myData3 = open("path/to/file.tsv", "\t", true);
 * --------------------
 */
CSV open( string filePath, string separator = ",", bool containHeader = false, string[] comment = [], string metadaLine = "" ){
    size_t[string]  header;
    string[][]      data        = new string[][](50);
    string          fullLine    = "";
    size_t          index       = 0;
    foreach(char[] line; new BufferedFile( filePath )){
        bool isCommentLine = false;
        foreach( com; comment ){
            if( com.length <= line.length && line[0..com.length] == com )
                isCommentLine = true;
        }
        if ( isCommentLine ) continue;
        else if ( line[$-1] == '\\' )
            fullLine ~= line;
        else{
            fullLine            = fullLine.stripRight();
            fullLine            ~= line.stripLeft();
            string[] columns    = fullLine.split(separator);
            if( index == 0 ){
                if( containHeader){                                     // if first line is a header
                    foreach(counter, key; columns)
                        header[key] = counter;                          // store it, key = column number
                }
                else{                                                   // otherwise add to data at right index
                    data[index] =  columns;
                    index++;                                            // increment index for not override this information
                }
            }
            else{
                if( index == data.length )                              // if data array is full
                    data.length = data.length + 50;                     // resize array by add 50 new fields
                data[index] = columns;                                  // store data at right index
                index++;                                                // increment index for not override this information
            }
            fullLine = "";
        }
    }
    data.length = index;                                                // resize data array for match exactly with the number of fields
    return new CSV(header, data);
}

/**
 * re-arrange data to line, cost CPU
 * Examples:
 * --------------------
 * string[][] dataInColumn  = [["1", "4"], ["2", "5"], ["3", "6"]];
 * string[][] dataInLine    = dataColumnToDataline( dataInColumn);
 * writeln( dataInLine );
 * => [["1", "2", "3"], ["4", "5", "6"]];
 * --------------------
 */
string[][] dataColumnToDataline( string[][] dataInColumn ){
    string[][] result;
    if( dataInColumn.length > 0 && dataInColumn[0].length > 0)
        result = new string[][]( dataInColumn[0].length, dataInColumn.length ); // set array to right size
    foreach( cindex, column; dataInColumn){                                     // for each column
        foreach( lindex, cell; column ){                                        // read each cell
            result[lindex][cindex] = cell;                                      // set value in cell in result
        }
    }
    return result;                                                              // now data is a reference to result
}

class CSV{
    private:
        size_t[string]  _header;
        string[][]      _data;

        size_t getIndex(string key){
            size_t index;
            if(key !in _header)                                                 // check if given key is in header
                throw new Exception( format( "Key: %s is not in header!" ) );
            else
                index = _header[key];
            return index;                                                       // return corresponding index for given key
        }

    public:
        /**
         * construct CSV file, this class could be usefull for access data in a csv file. Data are in memory so if you load
         * a huge file, coresponding object will take some memory.
         * Examples:
         * --------------------
         *
         * import csv;
         * string[]     header          = ["male", "female", "old"];
         * string[][]   data            = [["john", "smith", "andrew"], ["Ainsley", "Elizabeth", "Haley"], ["18", "30", "60"];
         * CSV          csvFile         = new CSV( header, data );
         * string[]     line2           = csvFile.getLine( 2 );     // get line 2
         * string[]     line25          = csvFile.getLine( 2, 5 );  // get line 2 to 5
         * string[]     column3         = csvFile[3];               // get column 3
         * string[]     columnKey       = csvFile["male"];          // get column sum
         * string[][]   column13        = csvFile[1..3];            // get columns 1 to 3
         * string[][]   columnKey1Key2  = csvFile["male".."female"];// get columns from mean to sum
         * --------------------
         */
        this(ref size_t[string]  header, ref string[][] data){
            this._header = header;
            this._data   = data;
        }

        this(ref string[]  header, ref string[][] data){
            foreach(size_t count, colHeader, header)
                this._header[colHeader] = count;
            this._data   = data;
        }

        this(ref string[][] data){
            this._header = null;
            this._data   = data;
        }

        /**
         * opIndex overload operator []. this method take a string for match to a key in header
         */
        string[] opIndex( string key ){
            return opIndex( getIndex(key) );                                    // call opIndex(size_t position)
        }

        /**
         * opIndex overload operator []. This method take a integer for get column at this position
         */
        string[] opIndex( size_t position ){
            string[] column = new string[]( _data.length );                     // set size to column
            foreach(index, line; _data){                                        // iterate over data
                column[index] = line[position];                                 // set value at right position
            }
            return column;                                                      // return column
        }

        /**
         * opSlice overload slicing [x..y]. This method take two key, each key need to match with a field in header.
         * This method cost CPU process
         * Returns: a range of columns
         */
        string[][] opSlice( string key1, string key2 ){
            size_t position1 = getIndex( key1 );                                // get position1 corresponding to first key
            size_t position2 = getIndex( key2 );                                // get position2 corresponding to second key
            return opSlice( position1, position2 );                             // call opSlice( size_t position1, size_t position2 )
        }

        /**
         * opSlice overload slicing [x..y]. This method take two integer.
         * This method cost CPU process
         * Returns: a range of columns
         */
        string[][] opSlice(size_t x, size_t y ){
            string[][]  columns  = new string[][]( _data.length, abs(x-y) );
            size_t      min      = cast(size_t)fmin( x, y );
            size_t      max      = cast(size_t)fmax( x, y );
            foreach(index, line; data){                                         // iterate over data
                foreach( colNumber; min..max )                                  // for each column
                    columns[index][colNumber] = line[colNumber];                // set value at right position
            }

            return ( x > y ? columns : columns.reverse);                        // return columns

        }

        /**
         * getLine return correponding line to number given
         * This method cost nothing for CPU
         */
        string[] getLine(size_t number){
            return _data[number];
        }

        /**
         * getSlicedLines return correponding range of lines to numbers given
         * This method cost nothing for CPU
         * by example line 2 to 5
         */
        string[][] getSlicedLines(size_t number1, size_t number2){
            return _data[number1..number2+1];
        }

        /**
         * length is a method for know how many line are stored in this object
         *
         * Returns: data length stored in this object
         */
        @property size_t length(){
            size_t size = 0;
            if( header !is null )
                size += _header.length;
            if( data !is null )
                size += _data.length;
            return size;
        }

        /**
         * Returns: data array
         */
        @property string[][] data(){
            return _data;
        }

        /**
         * Returns: header array
         */
        @property size_t[string] header(){
            return _header;
        }

        /**
         * Returns: data and header
         */
        @property string[][] allData(){
            size_t      position= 0;
            string[][]  array   = new string[][]( length, _header.length );
            if( header !is null ){
                size_t index = 0;
                foreach( value, key; _header)
                    array[position][index]   = value;
                position++;
            }
            if( array !is null )
                array[position..$] = _data;
            return array;
        }


        /**
         * write a CSV file
         *
         * Parameter mode can take: r, w, a values
         * Examples:
         * --------------------
         * import csv.d;
         * CSV csv = new CSV("/path/to/file.csv");
         * writeCSV( "~/path/to/output1.csv", csv );
         * writeCSV( "~/path/to/output2.tsv", csv, "\t" );
         * writeCSV( "~/path/to/output3.psv", csv, "|", "a" );
         * --------------------
         */
        void writeCSV( string filePath, string separator = ",", string mode = "w"){
            if( mode != "w" || mode != "a" )
                throw new Exception( format( "mode: %s is not supported! Choose valid mode: a, w", mode ) );
            File file = File( filePath , mode );                            // open file
            scope(exit) file.close;                                         // close file before quit
            foreach( lineSplitted; data ){                                  // for each line in data
                string line = join( lineSplitted, separator);               // join array with right separator example with separtor = "," ["peter", "paul","jerry"] => "peter,paul,jerry"
                file.write( line );                                         // write line in file
            }
        }
}
