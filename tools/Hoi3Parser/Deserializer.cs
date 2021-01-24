using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Hoi3Parser
{
    public class Deserializer
    {
        private const string replaceValue = "ParserTempReplacement";

        private string basePath;
        private Encoding encoding;

        private Deserializer() { }
        public Deserializer(string basePath, Encoding encoding)
        {
            this.basePath = basePath;
            this.encoding = encoding;
        }

        public List<Element> GetElementsFromFile(string subPath)
        {
            var fileText = File.ReadAllLines(Path.Combine(basePath, subPath), encoding).ToList();

            var stringLines = new List<string>();
            fileText.ForEach(line => stringLines.AddRange(ReadLine(line)));

            var elements = new List<Element>();
            for (int i = 0; i < stringLines.Count; i++)
            {
                if (i > 1 && i < stringLines.Count - 1 && stringLines[i] == "{")
                    elements.Add(ParseElement(stringLines, i + 2, stringLines[i - 2], out i, subPath));
            }

            var test = "";
            elements.ForEach(x => test += x.ToJson());

            return elements;
        }

        private Element ParseElement(List<string> lines, int index, string name, out int runningIndex, string file = "")
        {
            var attributes = new List<Attribute>();
            var subElements = new List<Element>();
            int i;
            for (i = index;  i < lines.Count; i++)
                if (lines[i] == "}")
                {
                   runningIndex = i;
                   return new Element(subElements, attributes, name, file);
                }
                else if (lines[i] == "=")
                {
                    if (lines[i + 1] == "{")
                        subElements.Add(ParseElement(lines, i + 2, lines[i - 1], out i));
                    else
                        attributes.Add(new Attribute(lines[i - 1], lines[i + 1]));
                }
            runningIndex = i;
            return new Element(subElements, attributes, name, null);
        }

        private List<string> ReadLine(string line)
        {
            line = line.RemoveComments();
            if (line.IsEmptyLine()) return new List<string>();

            MatchCollection matches;
            line = line.ReplaceStrings(replaceValue, out matches);

            var elementStrings = line.SplitElements();

            foreach (var match in matches.Cast<Match>().Select((Match x, int i) => new { value = x.Value, index = i }))
            {
                var element = elementStrings.FindIndex(x => x == $"{replaceValue}{match.index}");
                if (element > -1)
                    elementStrings[element] = elementStrings[element].Replace($"{replaceValue}{match.index}", match.value);
            }

            return elementStrings.Select(x => x.Trim('\t')).ToList();
        }
    }
}
