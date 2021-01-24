namespace Hoi3Parser
{
    public class Attribute
    {
        public string Name { get; private set; }
        public string Value { get; private set; }

        private Attribute() { }

        public Attribute(string name, string value)
        {
            Name = name;
            Value = value;
        }

        public override string ToString()
        {
            return $"{Name}: {Value}";
        }

        public string ToJson() => $"\"{Name}\": \"{Value}\"";
    }
}
