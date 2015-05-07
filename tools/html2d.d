#!/usr/bin/env rdmd

import std.process;
import std.conv;
import std.string;
import std.algorithm;
import std.json;
import std.array;
import std.file;
import std.stdio;
import std.regex;
import std.path;

class Node
{
    string type; // true text: false tag
    string content;
}
    
class Html2D
{
static:
    Node[] list;
    int codeIndent = 2;
    enum tagMaxLen = 100;
    string displayCode  ;
    string[] varlist;
    string[] nestedTag = [];


    string indent()
    {
        string idt = "";
        for(int i=0; i<codeIndent*4; i++) {
            idt ~= ' ';
        }
        return idt;
    }

    string echoCode(string str)
    {
        if(str[0] == '\n')
        {
            str = str[1 .. $];
        }
        else if (str[0 .. 2] == "\r\n") {
            str = str[2 .. $];
        }

        for(ulong i=str.length; i>0; i--) {
            if (str[i-1] == ' ') {
                continue;
            }
            if (str[i-1] == '\n' || str[i-1] == '\r') {
                str = str[0 .. i];
            }
            break;
        }
        string code = "";
        code ~= indent() ~ "response.write(\"";
        foreach(c; str) {
            if (c == '\\' || c == '"') {
                code ~= '\\';
            }
            code ~= c;
        }
        code ~= "\");\n";
        displayCode ~= code;
        return code;
    }

    string varCode(string str)
    {
        string code = "";
        code ~= indent() ~ "response.write(" ~ str ~ ");\n";
        displayCode ~= code;
        varlist ~= str;
        return code;
    }

    string ifCode(string str) {
        ptrdiff_t testPos = indexOf(str, "test");
        if (testPos == -1) {
            throw new Exception("if syntax error, not find test property");
        }
        ptrdiff_t eqPos = indexOf(str, "=", testPos);
        if (eqPos == -1) {
            throw new Exception("if tag missing '='");
        }
        ptrdiff_t quoPos = indexOf(str, "\"", eqPos);
        if (quoPos == -1) {
            throw new Exception("test attr missing \"");
        }
        ptrdiff_t quoEndPos = indexOf(str, "\"", quoPos+1);
        if (quoEndPos == -1) {
            throw new Exception("test attr missing end \"");
        }
        string exp = str[quoPos+1 .. quoEndPos];
        auto code = indent() ~ "if (" ~ replace(exp, "'", "\"") ~ ") {\n";

        displayCode ~= code;
        
        /* 
        auto tmpVars = splitter(exp, regex("[><&+/=* ]"));
        string[] vars;
        foreach(var; tmpVars) {
            if (var == "" || isNumeric(var) || var[0] == '\'') {
                continue;
            }
            vars ~= var;
        }
        varlist ~= vars;
        */
        return code;
    }

    string endCode() {
        string code = indent()~ "}\n"; 
        displayCode ~= code;
        return code;
    }

    string foreachCode(string str) {
        string rawStr = str[7 .. $].removechars(" ");
        
        ptrdiff_t keyPos = indexOf(rawStr, "key=\"");
        ptrdiff_t keystart = keyPos + 5;
        string key = "";
        if (keyPos != -1) {
            ptrdiff_t keyend = indexOf(rawStr, '"', keystart);
            key = rawStr[keystart .. keyend];
        }

        ptrdiff_t valuePos = indexOf(rawStr, "value=\"");
        if (valuePos == -1) {
            throw new Exception("foreach missing value attr");
        }
        ptrdiff_t valuestart = valuePos + 7;
        ptrdiff_t valueend = indexOf(rawStr, '"', valuestart);
        if (valueend == -1) {
            new Exception("value attr missing '\"'");
        }
        string value = rawStr[valuestart .. valueend];
        ptrdiff_t listPos = indexOf(rawStr, "list=\"");
        if (listPos == -1) {
            new Exception("foreach missing list attr");
        }
        ptrdiff_t liststart = listPos + 6;
        ptrdiff_t listend = indexOf(rawStr, '"', liststart);
        if (listend == -1) {
            new Exception("list attr missing '\"'");
        }
        string list = rawStr[liststart .. listend];

        string code = "";
        code ~= indent() ~ "foreach (";
        if (key != "") {
            code ~= key ~", ";
        }
        code ~= value ~ "; " ~ list ~ ") {\n";
        displayCode ~= code;
        return code;
    }

    int genCode(int nodPos)
    {
        if (nodPos >= list.length) {
            return 0;
        }
        // todo: toNodeList exp
        if (list[nodPos].type == "echo") {
            echoCode(list[nodPos].content);
        }
        else if(list[nodPos].type == "var") {
            varCode(list[nodPos].content);
        }
        else if(list[nodPos].type == "if") {
            ifCode(list[nodPos].content);
            codeIndent ++;
        }
        else if(list[nodPos].type == "/if") {
            codeIndent --;
            endCode();       
        }
        else if(list[nodPos].type == "/foreach") {
            codeIndent --;
            endCode();
        }
        else if(list[nodPos].type == "foreach") {
            foreachCode(list[nodPos].content);
            codeIndent ++;
        }
        return genCode(nodPos+1);

    }

    void addListItem(string type, string content)
    {
        auto newNode = new Node;
        newNode.type = type;
        newNode.content = content;
        list ~= newNode;   
    }

    void toNodeList(string data)
    {
        uint line = 1;
        string text;
        for(ulong i=0; i<data.length; i++)
        {
            if (data[i] == '\n') {
                line ++;
            }
            if (data[i] == '<') {
                ++i;
                if ((i+2 <= data.length && data[i .. i+2] == "if" && data[i+2] !='r') ) {
                    addListItem("echo", text);
                    text = [];
                    ulong pos = indexOf(data, '"', i);
                    if (pos == -1) {
                        throw new Exception("if tag missing first '\"' at line(" ~ to!string(line) ~")");
                    }
                    pos = indexOf(data, '"', pos +1);
                    if (pos == -1) {
                        throw new Exception("if tag missing second '\"' at line(" ~ to!string(line) ~")");
                    }
                    pos = indexOf(data, ">", pos);
                    if (pos == -1) {
                        throw new Exception("tag not closed at line(" ~ to!string(line) ~ "):" ~ data[i-1 .. 100]);
                    }
                    addListItem("if", data[i .. pos]);
                    i = pos;
                } 
                else if(i+7 <= data.length && data[i .. i+7] == "foreach") {
                    addListItem("echo", text);
                    text = [];
                    ptrdiff_t pos = indexOf(data[i .. i+tagMaxLen], '>');
                    if (pos == -1) {
                        throw new Exception("tag not closed at line(" ~ to!string(line) ~ "):" ~ data[i-1 .. 100]);
                    }
                    addListItem("foreach", data[i .. i+pos]);
                    i += pos ;
                }
                else if (i+6 <= data.length && data[i .. i+6] == "else/>"){
                    addListItem("echo", text);
                    text = [];
                    addListItem("else", data[i .. i+4]);
                    i += 6;
                }
                else if (i+4 <= data.length && data[i .. i+4] == "/if>") {
                    addListItem("echo", text);
                    text = [];
                    addListItem("/if", data[i .. i+3]);
                    i += 4;
                }
                else if (i+9 <= data.length && data[i .. i+9] == "/foreach>") {
                    addListItem("echo", text);
                    text = [];
                    addListItem("/foreach", data[i .. i+8]);
                    i += 9;
                }
                else { // html tag
                    --i;
                    text ~= data[i];
                }
            }
            else if (data[i] == '[') {
                ++i;
                if (data[i] == '[') {
                    text ~= '[';
                    continue;
                }
                else {
                    addListItem("echo", text);
                    text = [];
                    ulong end = min(i+tagMaxLen, data.length);
                    ptrdiff_t pos = indexOf(data[i .. end], ']');
                    if (pos == -1) {
                        throw new Exception("tag not closed at line(" ~ to!string(line) ~ "):" ~ data[i-1 .. i+ 100]);
                    }
                    addListItem("var", data[i .. i+pos]);
                    i += pos ;
                }
                
            }
            else {
                text ~= data[i];
            }
        }
        if (text.length >0) {
            addListItem("echo", text);
        }
    }
    
    string getCode(string fileName) {
        list = [];
        codeIndent = 2;
        displayCode = "";
        varlist = [];
        string data = cast(string)std.file.read(fileName);
        if (data == "") {
            return "";
        }
        toNodeList(data);
        genCode(0);
        return displayCode;
    }
}
void main(string[] args) 
{
    //auto f = cast(char[])std.file.read("dub.json");
    auto config = parseJSON(cast(char[])std.file.read("dub.json"));
    
    JSONValue paths;
    try paths = config["stringImportPaths"];
    catch(Exception e) {
        paths = JSONValue(["views"]);
    }
    foreach(ulong index, templatePath; paths)
    {
        foreach (string fileName; dirEntries( templatePath.str, SpanMode.depth))
        {
            if (isDir(fileName) || fileName[$-5 .. $] !=".html") {
                continue;
            }
            
            std.file.write(fileName[0 .. $-5] , Html2D.getCode(fileName));
        }
    }
}
