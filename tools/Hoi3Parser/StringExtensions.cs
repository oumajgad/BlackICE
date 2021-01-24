using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Hoi3Parser
{
    public static class StringExtensions
    {
        public static string RemoveComments(this string line)
        {
            var hashtagIndex = line.IndexOf('#');
            if (hashtagIndex != -1)
                line = line.Substring(0, hashtagIndex);
            return line;
        }
        public static bool IsEmptyLine(this string line) => string.IsNullOrEmpty(line) || string.IsNullOrWhiteSpace(line);

        public static string ReplaceStrings(this string line, string replaceValue, out MatchCollection matches)
        {
            var stringPattern = new Regex("\".*?\"");
            matches = stringPattern.Matches(line);
            var index = 0;
            foreach (Match match in matches)
            {
                line = stringPattern.Replace(line, replaceValue + index, 1);
                index++;
            }
            return line;
        }

        public static List<string> SplitElements (this string line)
        {
            var ret = new List<string>();
            var elementString = "";
            var specialPattern = new Regex("[ ={}]");
            foreach (var element in line)
            {
                if (specialPattern.IsMatch(element.ToString()))
                {
                    if (!string.IsNullOrEmpty(elementString))
                        ret.Add(elementString);
                    if (element != ' ')
                        ret.Add(element.ToString());
                    elementString = "";
                }
                else
                {
                    elementString += element;
                }
            }
            if (!string.IsNullOrEmpty(elementString))
                ret.Add(elementString);
            return ret;
        }
    }
}
