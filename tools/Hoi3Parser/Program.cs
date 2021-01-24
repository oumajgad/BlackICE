using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Hoi3Parser
{
    public static class Program
    {
        
        //private const string path = "";
        private const string basePath = @"";
        private const string subPath = @"";

        private static readonly Encoding encoding = Encoding.GetEncoding(1252);

        private const string replaceValue = "ParserTempReplacement";

        static void Main(string[] args)
        {
            var deserializer = new Deserializer(basePath, encoding);
            deserializer.GetElementsFromFile(subPath);
        }

        //static void Main(string[] args)
        //{
        //    var text = File.ReadAllLines(path, encoding).ToList();
        //    var lines = new List<string>();
        //    foreach (var line in text)
        //        lines.AddRange(ReadLine(line));
            

        //    var test = 1;
        //}

        //private static List<string> ReadLine(this string lineToRead)
        //{
        //    string line = lineToRead;

        //    var hashtagIndex = line.IndexOf('#');
        //    if (hashtagIndex != -1)
        //        line = lineToRead.Substring(0, hashtagIndex);

        //    if (string.IsNullOrEmpty(line) || string.IsNullOrWhiteSpace(line))
        //        return new List<string>();

        //    return line.TrimLine();
        //}

        //private static List<string> TrimLine(this string line)
        //{
        //    var stringPattern = new Regex("\".*?\"");            

        //    var matches = stringPattern.Matches(line);
        //    var index = 0;
        //    foreach (Match match in matches)
        //    {
        //        line = stringPattern.Replace(line, replaceValue + index, 1);
        //        index++;
        //    }

        //    line = line.Replace("\t", string.Empty);

        //    var test = new List<string>();
        //    var temp = "";
        //    var specialPattern = new Regex("[ ={}]");
        //    foreach (var element in line)
        //    {
        //        if (specialPattern.IsMatch(element.ToString()))
        //        {
        //            if (!string.IsNullOrEmpty(temp))
        //                test.Add(temp);
        //            if (element != ' ')
        //                test.Add(element.ToString());
        //            temp = "";
        //        } else
        //        {
        //            temp += element;
        //        }
        //    }
        //    if (!string.IsNullOrEmpty(temp))
        //        test.Add(temp);

        //    index = 0;
        //    foreach (Match match in matches)
        //    {
        //        test = test.Select(x => x.Replace(replaceValue + index, match.Value)).ToList();
        //        index++;
        //    }

        //    return test;
        //}

        //public static string ParseJson(List<string> lines)
        //{
        //    var jsonText = "";
        //    foreach (var line in lines.Select((x, i) => new { value = x, index = i }))
        //    {
        //        if (line.value == "=")
        //            jsonText += ":";
        //        else if (line.value == "}")
        //        {
        //            if (line.index < lines.Count - 1 && lines[line.index + 1] == "}")
        //                jsonText += $"{line.value}";
        //            else
        //                jsonText += $"{line.value},";
        //        }
        //        else if (line.value == "{")
        //            jsonText += $" {line.value}";
        //        else if (line.index > 0 && lines[line.index - 1] == "=")
        //        {
        //            if (line.index < lines.Count - 1 && lines[line.index + 1] == "}")
        //                jsonText += $"\"{line.value.Trim('"')}\"";
        //            else
        //                jsonText += $"\"{line.value.Trim('"')}\",";
        //        }
        //        else
        //            jsonText += $"\"{line.value.Trim('"')}\"";
        //    }
        //    return jsonText;
        //}
    }
}
