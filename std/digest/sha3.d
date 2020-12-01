/**
 * Computes SHA-3 hashes of arbitary data.
 *
 * References: NIST FIPS PUB 202
 * 
 * Source: $(PHOBOSSRC std/digest/sha3.d)
 */
module std.digest.sha3;

public import std.digest;

private immutable ulong[24] K_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
    0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
    0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
];
private immutable int[24] K_ROTC = [
     1,  3,  6, 10, 15, 21, 28, 36, 45, 55,  2, 14,
    27, 41, 56,  8, 25, 43, 62, 18, 39, 61, 20, 44
];
private immutable int[24] K_PI = [
    10,  7, 11, 17, 18, 3,  5, 16,  8, 21, 24, 4,
    15, 23, 19, 13, 12, 2, 20, 14, 22,  9,  6, 1
];

/**
 * Template API SHA-3/SHAKE implementation using the Keccak[1600] function.
 * Supports SHA-3-224, SHA-3-256, SHA-3-384, SHA-3-512, SHAKE-128, and SHAKE-256.
 * 
 * The digestSize parameter is in bits. However, it's easier to use the SHA3_224,
 * SHA3_256, SHA3_384, SHA3_512, SHAKE128, and SHAKE256 aliases.
 */
public struct KECCAK(uint digestSize, bool shake = false)
{
    static if (shake)
        static assert(digestSize == 128 || digestSize == 256,
            "digest size must be 128 or 256 bits for SHAKE");
    else
        static assert(digestSize == 224 || digestSize == 256 ||
            digestSize == 384 || digestSize == 512,
            "digest size must be 224, 256, 384, or 512 bits for SHA-3");

    @safe @nogc pure nothrow:

    enum
    {
        blockSize = digestSize, /// digest size in bits
        dgst_sz_bytes = blockSize >> 3, /// digest size in bytes
        delim = shake ? 0x1f : 0x06, /// delimiter when finishing
        rate = 200 - (blockSize >> 2), /// sponge rate
    }

    union
    {
        private ubyte[200] st;  /// state (8bit)
        private ulong[25] st64; /// state (64bit)
    }

    static assert(st64.sizeof == st.sizeof);

    private size_t pt; /// left-over pointer

    /**
     * Initiates the structure. Begins the SHA-3/SHAKE operation.
     *
     * This is better used when restarting the operation (e.g.,
     * for a file).
     */
    void start()
    {
        this = typeof(this).init;
    }

    /**
     * Feed the algorithm with data.
     *
     * Also implements the $(REF isOutputRange, std,range,primitives)
     * interface for `ubyte` and `const(ubyte)[]`.
     *
     * Params: input = Data input
     */
    void put(scope const(ubyte)[] input...)
    {
        size_t j = pt;
        const size_t len = input.length;

        for (size_t i; i < len; ++i)
        {
            st[j++] ^= input[i];
            if (j >= rate)
            {
                transform;
                j = 0;
            }
        }

        pt = j;
    }

    /**
     * Returns the finished hash. This also clears part of the state,
     * leaving just the final digest.
     */
    ubyte[dgst_sz_bytes] finish()
    {
        st[pt] ^= delim;
        st[rate - 1] ^= 0x80;
        transform;

        st[dgst_sz_bytes .. $] = 0; // Zero possible sensitive data
        return st[0 .. dgst_sz_bytes];
    }

private:

    pragma(inline, true)
    ulong ROTL64(ulong x, ulong y) @safe @nogc pure nothrow
    {
        return (((x) << (y)) | ((x) >> (64 - (y))));
    }

    version (BigEndian)
    pragma(inline, true)
    void swap()
    {
        
        for (size_t i; i < 25; ++i)
            st64[i] = core.bitop.bswap(st64[i]);
    }

    void transform()
    {
        size_t i = void, j = void, r = void;
        ulong[5] bc = void;
        ulong t = void;

        version (BigEndian) swap;

        // Main iteration loop
        // Some loops were manually unrolled for performance reasons
        for (r = 0; r < 24; ++r)
        {
            // Theta
            for (i = 0; i < 5; i++)
                bc[i] = st64[i] ^ st64[i + 5] ^ st64[i + 10] ^ st64[i + 15] ^ st64[i + 20];

            for (i = 0; i < 5; i++)
            {
                t = bc[(i + 4) % 5] ^ ROTL64(bc[(i + 1) % 5], 1);
                for (j = 0; j < 25; j += 5)
                    st64[j + i] ^= t;
            }

            // Rho
            t = st64[1];
            for (i = 0; i < 24; i++)
            {
                j = K_PI[i];
                bc[0] = st64[j];
                st64[j] = ROTL64(t, K_ROTC[i]);
                t = bc[0];
            }

            // Chi
            for (j = 0; j < 25; j += 5)
            {
                /*for (i = 0; i < 5; ++i)
                    bc[i] = st64[j + i];*/
                bc[0] = st64[j];
                bc[1] = st64[j + 1];
                bc[2] = st64[j + 2];
                bc[3] = st64[j + 3];
                bc[4] = st64[j + 4];
                
                /*for (i = 0; i < 5; ++i)
                    st64[j + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];*/
                st64[j] ^= (~bc[1]) & bc[2];
                st64[j + 1] ^= (~bc[2]) & bc[3];
                st64[j + 2] ^= (~bc[3]) & bc[4];
                st64[j + 3] ^= (~bc[4]) & bc[0];
                st64[j + 4] ^= (~bc[0]) & bc[1];
            }

            // Iota
            st64[0] ^= K_RC[r];
        }

        version (BigEndian) swap;
    }
}

public alias SHA3_224 = KECCAK!(224, false); /// Alias for SHA3-224
public alias SHA3_256 = KECCAK!(256, false); /// Alias for SHA3-256
public alias SHA3_384 = KECCAK!(384, false); /// Alias for SHA3-384
public alias SHA3_512 = KECCAK!(512, false); /// Alias for SHA3-512
public alias SHAKE128 = KECCAK!(128, true);  /// Alias for SHAKE-128
public alias SHAKE256 = KECCAK!(256, true);  /// Alias for SHAKE-256

@safe unittest
{
    assert(isDigest!SHA3_224);
    assert(isDigest!SHA3_256);
    assert(isDigest!SHA3_384);
    assert(isDigest!SHA3_512);
    assert(isDigest!SHAKE128);
    assert(isDigest!SHAKE256);
}

/// Convience alias for $(REF digest, std,digest) using the SHA-3 implementation.
auto sha3_224Of(T...)(T data)
{
    return digest!(SHA3_224, T)(data);
}
/// Convience alias for $(REF digest, std,digest) using the SHA-3 implementation.
auto sha3_256Of(T...)(T data)
{
    return digest!(SHA3_256, T)(data);
}
/// Convience alias for $(REF digest, std,digest) using the SHA-3 implementation.
auto sha3_384Of(T...)(T data)
{
    return digest!(SHA3_384, T)(data);
}
/// Convience alias for $(REF digest, std,digest) using the SHA-3 implementation.
auto sha3_512Of(T...)(T data)
{
    return digest!(SHA3_512, T)(data);
}
/// Convience alias for $(REF digest, std,digest) using the SHA-3 implementation.
auto shake128Of(T...)(T data)
{
    return digest!(SHAKE128, T)(data);
}
/// Convience alias for $(REF digest, std,digest) using the SHA-3 implementation.
auto shake256Of(T...)(T data)
{
    return digest!(SHAKE256, T)(data);
}

@system unittest
{
    import std.conv : hexString;
    
    ubyte[] r_sha3_224 = cast(ubyte[])hexString!"6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7";
    ubyte[] r_sha3_256 = cast(ubyte[])hexString!"a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a";
    ubyte[] r_sha3_384 = cast(ubyte[])hexString!("0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2a"
        ~"c3713831264adb47fb6bd1e058d5f004");
    ubyte[] r_sha3_512 = cast(ubyte[])hexString!("a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a6"
        ~"15b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26");
    ubyte[] r_shake128 = cast(ubyte[])hexString!"7f9c2ba4e88f827d616045507605853e";
    ubyte[] r_shake256 = cast(ubyte[])hexString!"46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f";

    SHA3_224 dgst_sha3_224;
    dgst_sha3_224.put(cast(ubyte[])"abcdef");
    dgst_sha3_224.start();
    dgst_sha3_224.put(cast(ubyte[])"");
    assert(dgst_sha3_224.finish() == r_sha3_224);

    SHA3_256 dgst_sha3_256;
    dgst_sha3_256.put(cast(ubyte[])"abcdef");
    dgst_sha3_256.start();
    dgst_sha3_256.put(cast(ubyte[])"");
    assert(dgst_sha3_256.finish() == r_sha3_256);

    SHA3_384 dgst_sha3_384;
    dgst_sha3_384.put(cast(ubyte[])"abcdef");
    dgst_sha3_384.start();
    dgst_sha3_384.put(cast(ubyte[])"");
    assert(dgst_sha3_384.finish() == r_sha3_384);

    SHA3_512 dgst_sha3_512;
    dgst_sha3_512.put(cast(ubyte[])"abcdef");
    dgst_sha3_512.start();
    dgst_sha3_512.put(cast(ubyte[])"");
    assert(dgst_sha3_512.finish() == r_sha3_512);

    SHAKE128 dgst_shake128;
    dgst_shake128.put(cast(ubyte[])"abcdef");
    dgst_shake128.start();
    dgst_shake128.put(cast(ubyte[])"");
    assert(dgst_shake128.finish() == r_shake128);

    SHAKE256 dgst_shake256;
    dgst_shake256.put(cast(ubyte[])"abcdef");
    dgst_shake256.start();
    dgst_shake256.put(cast(ubyte[])"");
    assert(dgst_shake256.finish() == r_shake256);

    auto digest224      = sha3_224Of("a");
    auto digest256      = sha3_256Of("a");
    auto digest384      = sha3_384Of("a");
    auto digest512      = sha3_512Of("a");
    auto digestshake128 = shake128Of("a");
    auto digestshake256 = shake256Of("a");
    assert(digest224 == cast(ubyte[]) hexString!"9e86ff69557ca95f405f081269685b38e3a819b309ee942f482b6a8b");
    assert(digest256 == cast(ubyte[]) hexString!"80084bf2fba02475726feb2cab2d8215eab14bc6bdd8bfb2c8151257032ecd8b");
    assert(digest384 == cast(ubyte[]) hexString!("1815f774f320491b48569efec794d249eeb59aae46d22bf77dafe25c5edc28d"
        ~"7ea44f93ee1234aa88f61c91912a4ccd9"));
    assert(digest512 == cast(ubyte[]) hexString!("697f2d856172cb8309d6b8b97dac4de344b549d4dee61edfb4962d8698b7fa8"
        ~"03f4f93ff24393586e28b5b957ac3d1d369420ce53332712f997bd336d09ab02a"));
    assert(digestshake128 == cast(ubyte[]) hexString!"85c8de88d28866bf0868090b3961162b");
    assert(digestshake256 == cast(ubyte[]) hexString!"867e2cb04f5a04dcbd592501a5e8fe9ceaafca50255626ca736c138042530ba4");

    digest224      = sha3_224Of("abc");
    digest256      = sha3_256Of("abc");
    digest384      = sha3_384Of("abc");
    digest512      = sha3_512Of("abc");
    digestshake128 = shake128Of("abc");
    digestshake256 = shake256Of("abc");
    assert(digest224 == cast(ubyte[]) hexString!"e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf");
    assert(digest256 == cast(ubyte[]) hexString!"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532");
    assert(digest384 == cast(ubyte[]) hexString!("ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b"
        ~"298d88cea927ac7f539f1edf228376d25"));
    assert(digest512 == cast(ubyte[]) hexString!("b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712"
        ~"e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0"));
    assert(digestshake128 == cast(ubyte[]) hexString!"5881092dd818bf5cf8a3ddb793fbcba7");
    assert(digestshake256 == cast(ubyte[]) hexString!"483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739");

    digest224      = sha3_224Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    digest256      = sha3_256Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    digest384      = sha3_384Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    digest512      = sha3_512Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    digestshake128 = shake128Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    digestshake256 = shake256Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    assert(digest224 == cast(ubyte[]) hexString!"8a24108b154ada21c9fd5574494479ba5c7e7ab76ef264ead0fcce33");
    assert(digest256 == cast(ubyte[]) hexString!"41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376");
    assert(digest384 == cast(ubyte[]) hexString!("991c665755eb3a4b6bbdfb75c78a492e8c56a22c5c4d7e429bfdbc32b9d4ad5"
        ~"aa04a1f076e62fea19eef51acd0657c22"));
    assert(digest512 == cast(ubyte[]) hexString!("04a371e84ecfb5b8b77cb48610fca8182dd457ce6f326a0fd3d7ec2f1e91636"
        ~"dee691fbe0c985302ba1b0d8dc78c086346b533b49c030d99a27daf1139d6e75e"));
    assert(digestshake128 == cast(ubyte[]) hexString!"1a96182b50fb8c7e74e0a707788f55e9");
    assert(digestshake256 == cast(ubyte[]) hexString!"4d8c2dd2435a0128eefbb8c36f6f87133a7911e18d979ee1ae6be5d4fd2e3329");

    ubyte[] onemilliona = new ubyte[1000000];
    onemilliona[] = 'a';
    digest224      = sha3_224Of(onemilliona);
    digest256      = sha3_256Of(onemilliona);
    digest384      = sha3_384Of(onemilliona);
    digest512      = sha3_512Of(onemilliona);
    digestshake128 = shake128Of(onemilliona);
    digestshake256 = shake256Of(onemilliona);
    assert(digest224 == cast(ubyte[]) hexString!"d69335b93325192e516a912e6d19a15cb51c6ed5c15243e7a7fd653c");
    assert(digest256 == cast(ubyte[]) hexString!"5c8875ae474a3634ba4fd55ec85bffd661f32aca75c6d699d0cdcb6c115891c1");
    assert(digest384 == cast(ubyte[]) hexString!("eee9e24d78c1855337983451df97c8ad9eedf256c6334f8e948d252d5e0e768"
        ~"47aa0774ddb90a842190d2c558b4b8340"));
    assert(digest512 == cast(ubyte[]) hexString!("3c3a876da14034ab60627c077bb98f7e120a2a5370212dffb3385a18d4f3885"
        ~"9ed311d0a9d5141ce9cc5c66ee689b266a8aa18ace8282a0e0db596c90b0a7b87"));
    assert(digestshake128 == cast(ubyte[]) hexString!"9d222c79c4ff9d092cf6ca86143aa411");
    assert(digestshake256 == cast(ubyte[]) hexString!"3578a7a4ca9137569cdf76ed617d31bb994fca9c1bbf8b184013de8234dfd13a");
}

/**
 * OOP API SHA-3 implementations.
 * See `std.digest` for differences between template and OOP API.
 *
 * This is an alias for $(D $(REF WrapperDigest, std,digest)!SHA1), see
 * there for more information.
 */

alias SHA3_224Digest = WrapperDigest!SHA3_224; /// Ditto
alias SHA3_256Digest = WrapperDigest!SHA3_256; /// Ditto
alias SHA3_384Digest = WrapperDigest!SHA3_384; /// Ditto
alias SHA3_512Digest = WrapperDigest!SHA3_512; /// Ditto
alias SHAKE128Digest = WrapperDigest!SHAKE128; /// Ditto
alias SHAKE256Digest = WrapperDigest!SHAKE256; /// Ditto
