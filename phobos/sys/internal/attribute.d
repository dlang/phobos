module phobos.sys.internal.attribute;

version (DigitalMars)
{
    enum hidden;
}
else
{
    public import core.attribute : hidden;
}
