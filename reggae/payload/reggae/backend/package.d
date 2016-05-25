module reggae.backend;

public import reggae.backend.binary;

version(minimal) {
} else {
    public import reggae.backend.ninja;
    public import reggae.backend.make;
    public import reggae.backend.tup;
}
