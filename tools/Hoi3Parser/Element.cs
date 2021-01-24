using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Hoi3Parser
{
    public class Element
    {
        public List<Element> SubElements { get; private set; }
        public List<Attribute> Attributes { get; private set; }
        public string Name { get; private set; }
        public string File { get; private set; }

        private Element() { }
        public Element(List<Element> subElements, List<Attribute> attributes, string name, string file)
        {
            SubElements = subElements;
            Attributes = attributes;
            Name = name;
            File = file;
        }

        public override string ToString()
        {
            return Name;
        }

        public string ToJson()
        {
            string ret = $"\"{Name}\": {{";
            for (var i = 0; i < Attributes.Count; i++)
            {
                if (i == Attributes.Count - 1)
                    ret += $" {Attributes[i].ToJson()}";
                else
                    ret += $" {Attributes[i].ToJson()},";
            }
            ret += " \"SubObjects\": {";
            for (var i = 0; i < SubElements.Count; i++)
            {
                if (i == SubElements.Count - 1)
                    ret += $" {SubElements[i].ToJson()}";
                else
                    ret += $" {SubElements[i].ToJson()},";
            }
            ret += " }";
            return ret;

        }

    }
}
