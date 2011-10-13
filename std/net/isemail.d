/**
 * Validates an email address according to RFCs 5321, 5322 and others.
 *
 * Authors: Dominic Sayers <dominic@sayers.cc>, Jacob Carlborg
 * Copyright: Dominic Sayers, Jacob Carlborg 2008-.
 * Test schema documentation: Copyright © 2011, Daniel Marschall
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Version: 3.0.13 - Version 3.0 of the original PHP implementation: $(LINK http://www.dominicsayers.com/isemail)
 *
 * Standards:
 *         $(UL
 *             $(LI RFC 5321)
 *             $(LI RFC 5322)
 *          )
 *
 * References:
 *         $(UL
 *             $(LI $(LINK http://www.dominicsayers.com/isemail))
 *             $(LI $(LINK http://tools.ietf.org/html/rfc5321))
 *             $(LI $(LINK http://tools.ietf.org/html/rfc5322))
 *          )
 *
 * Source: $(PHOBOSSRC std/net/_isemail.d)
 */
module std.net.isemail;

import std.algorithm : equal, uniq, filter, contains = canFind;
import std.range : ElementType;
import std.array;
import std.ascii;
import std.conv;
import std.exception : enforce;
import std.regex;
import std.string;
import std.traits;
import std.utf;

/**
 * Check that an email address conforms to RFCs 5321, 5322 and others.
 *
 * As of Version 3.0, we are now distinguishing clearly between a Mailbox as defined
 * by RFC 5321 and an addr-spec as defined by RFC 5322. Depending on the context,
 * either can be regarded as a valid email address. The RFC 5321 Mailbox specification
 * is more restrictive (comments, white space and obsolete forms are not allowed).
 *
 * Note: The DNS check is currently not implemented.
 *
 * Params:
 *     email = The email address to check
 *     checkDNS = If CheckDns.yes then a DNS check for MX records will be made
 *     errorLevel = Determines the boundary between valid and invalid addresses.
 *                  Status codes above this number will be returned as-is,
 *                  status codes below will be returned as EmailStatusCode.valid.
 *                  Thus the calling program can simply look for EmailStatusCode.valid
 *                  if it is only interested in whether an address is valid or not. The
 *                  $(D_PARAM errorLevel) will determine how "picky" isEmail() is about
 *                  the address.
 *
 *                  If omitted or passed as EmailStatusCode.none then isEmail() will
 *                  not perform any finer grained error checking and an address is
 *                  either considered valid or not. Email status code will either be
 *                  EmailStatusCode.valid or EmailStatusCode.error.
 *
 * Returns: an EmailStatus, indicating the status of the email address.
 */
EmailStatus isEmail (Char) (const(Char)[] email, CheckDns checkDNS = CheckDns.no,
    EmailStatusCode errorLevel = EmailStatusCode.none) if (isSomeChar!(Char))
{
    alias const(Char)[] tstring;

    int threshold;
    bool diagnose;

    if (errorLevel == EmailStatusCode.any || errorLevel == EmailStatusCode.none)
    {
        threshold = EmailStatusCode.valid;
        diagnose = errorLevel == EmailStatusCode.any;
    }

    else
    {
        diagnose = true;

        switch (errorLevel)
        {
            case EmailStatusCode.warning: threshold = threshold; break;
            case EmailStatusCode.error: threshold = EmailStatusCode.valid; break;
            default: threshold = errorLevel;
        }
    }

    auto returnStatus = [EmailStatusCode.valid];
    auto context = EmailPart.componentLocalPart;
    auto contextStack = [context];
    auto contextPrior = context;
    tstring token = "";
    tstring tokenPrior = "";
    tstring[EmailPart] parseData = [EmailPart.componentLocalPart : "", EmailPart.componentDomain : ""];
    tstring[][EmailPart] atomList = [EmailPart.componentLocalPart : [""], EmailPart.componentDomain : [""]];
    auto elementCount = 0;
    auto elementLength = 0;
    auto hyphenFlag = false;
    auto endOrDie = false;
    auto crlfCount = int.min; // int.min == not defined

    foreach (ref i, e ; email)
    {
        token = email.get(i, e);

        switch (context)
        {
            case EmailPart.componentLocalPart:
                switch (token)
                {
                    case Token.openParenthesis:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.comment :
                                EmailStatusCode.deprecatedComment;

                        else
                        {
                            returnStatus ~= EmailStatusCode.comment;
                            endOrDie = true;
                        }

                        contextStack ~= context;
                        context = EmailPart.contextComment;
                    break;

                    case Token.dot:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.errorDotStart :
                                EmailStatusCode.errorConsecutiveDots;

                        else
                        {
                            if (endOrDie)
                                returnStatus ~= EmailStatusCode.deprecatedLocalPart;
                        }

                        endOrDie = false;
                        elementLength = 0;
                        elementCount++;
                        parseData[EmailPart.componentLocalPart] ~= token;

                        if (elementCount >= atomList[EmailPart.componentLocalPart].length)
                            atomList[EmailPart.componentLocalPart] ~= "";

                        else
                            atomList[EmailPart.componentLocalPart][elementCount] = "";
                    break;

                    case Token.doubleQuote:
                        if (elementLength == 0)
                        {
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.rfc5321QuotedString :
                                EmailStatusCode.deprecatedLocalPart;

                            parseData[EmailPart.componentLocalPart] ~= token;
                            atomList[EmailPart.componentLocalPart][elementCount] ~= token;
                            elementLength++;
                            endOrDie = true;
                            contextStack ~= context;
                            context = EmailPart.contextQuotedString;
                        }

                        else
                            returnStatus ~= EmailStatusCode.errorExpectingText;
                    break;

                    case Token.cr:
                    case Token.space:
                    case Token.tab:
                        if ((token == Token.cr) && ((++i == email.length) || (email.get(i, e) != Token.lf)))
                        {
                            returnStatus ~= EmailStatusCode.errorCrNoLf;
                            break;
                        }

                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.foldingWhitespace :
                                EmailStatusCode.deprecatedFoldingWhitespace;

                        else
                            endOrDie = true;

                        contextStack ~= context;
                        context = EmailPart.contextFoldingWhitespace;
                        tokenPrior = token;
                    break;

                    case Token.at:
                        enforce(contextStack.length == 1, "Unexpected item on context stack");

                        if (parseData[EmailPart.componentLocalPart] == "")
                            returnStatus ~= EmailStatusCode.errorNoLocalPart;

                        else if (elementLength == 0)
                            returnStatus ~= EmailStatusCode.errorDotEnd;

                        else if (parseData[EmailPart.componentLocalPart].length > 64)
                            returnStatus ~= EmailStatusCode.rfc5322LocalTooLong;

                        else if (contextPrior == EmailPart.contextComment ||
                            contextPrior == EmailPart.contextFoldingWhitespace)
                                returnStatus ~= EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt;

                        context = EmailPart.componentDomain;
                        contextStack = [context];
                        elementCount = 0;
                        elementLength = 0;
                        endOrDie = false;
                    break;

                    default:
                        if (endOrDie)
                        {
                            switch (contextPrior)
                            {
                                case EmailPart.contextComment:
                                case EmailPart.contextFoldingWhitespace:
                                    returnStatus ~= EmailStatusCode.errorTextAfterCommentFoldingWhitespace;
                                break;

                                case EmailPart.contextQuotedString:
                                    returnStatus ~= EmailStatusCode.errorTextAfterQuotedString;
                                break;

                                default:
                                    throw new Exception("More text found where none is allowed, but unrecognised prior "
                                                        "context: " ~ to!(string)(contextPrior));
                            }
                        }

                        else
                        {
                            contextPrior = context;
                            auto c = token.front;

                            if (c < '!' || c > '~' || c == '\n' || Token.specials.contains(token))
                                returnStatus ~= EmailStatusCode.errorExpectingText;

                            parseData[EmailPart.componentLocalPart] ~= token;
                            atomList[EmailPart.componentLocalPart][elementCount] ~= token;
                            elementLength++;
                        }
                }
            break;

            case EmailPart.componentDomain:
                switch (token)
                {
                    case Token.openParenthesis:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt
                                : EmailStatusCode.deprecatedComment;

                        else
                        {
                            returnStatus ~= EmailStatusCode.comment;
                            endOrDie = true;
                        }

                        contextStack ~= context;
                        context = EmailPart.contextComment;
                    break;

                    case Token.dot:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.errorDotStart :
                                EmailStatusCode.errorConsecutiveDots;

                        else if (hyphenFlag)
                            returnStatus ~= EmailStatusCode.errorDomainHyphenEnd;

                        else
                        {
                            if (elementLength > 63)
                                returnStatus ~= EmailStatusCode.rfc5322LabelTooLong;
                        }

                        endOrDie = false;
                        elementLength = 0,
                        elementCount++;

                        //atomList[EmailPart.componentDomain][elementCount] = "";
                        atomList[EmailPart.componentDomain] ~= "";
                        parseData[EmailPart.componentDomain] ~= token;
                    break;

                    case Token.openBracket:
                        if (parseData[EmailPart.componentDomain] == "")
                        {
                            endOrDie = true;
                            elementLength++;
                            contextStack ~= context;
                            context = EmailPart.componentLiteral;
                            parseData[EmailPart.componentDomain] ~= token;
                            atomList[EmailPart.componentDomain][elementCount] ~= token;
                            parseData[EmailPart.componentLiteral] = "";
                        }

                        else
                            returnStatus ~= EmailStatusCode.errorExpectingText;
                    break;

                    case Token.cr:
                    case Token.space:
                    case Token.tab:
                        if (token == Token.cr && (++i == email.length || email.get(i, e) != Token.lf))
                        {
                            returnStatus ~= EmailStatusCode.errorCrNoLf;
                            break;
                        }

                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt
                                : EmailStatusCode.deprecatedFoldingWhitespace;

                        else
                        {
                            returnStatus ~= EmailStatusCode.foldingWhitespace;
                            endOrDie = true;
                        }

                        contextStack ~= context;
                        context = EmailPart.contextFoldingWhitespace;
                        tokenPrior = token;
                    break;

                    default:
                        if (endOrDie)
                        {
                            switch (contextPrior)
                            {
                                case EmailPart.contextComment:
                                case EmailPart.contextFoldingWhitespace:
                                    returnStatus ~= EmailStatusCode.errorTextAfterCommentFoldingWhitespace;
                                break;

                                case EmailPart.componentLiteral:
                                    returnStatus ~= EmailStatusCode.errorTextAfterDomainLiteral;
                                break;

                                default:
                                    throw new Exception("More text found where none is allowed, but unrecognised prior "
                                                        "context: " ~ to!(string)(contextPrior));
                            }

                        }

                        auto c = token.front;
                        hyphenFlag = false;

                        if (c < '!' || c > '~' || Token.specials.contains(token))
                            returnStatus ~= EmailStatusCode.errorExpectingText;

                        else if (token == Token.hyphen)
                        {
                            if (elementLength == 0)
                                returnStatus ~= EmailStatusCode.errorDomainHyphenStart;

                            hyphenFlag = true;
                        }

                        else if (!((c > '/' && c < ':') || (c > '@' && c < '[') || (c > '`' && c < '{')))
                            returnStatus ~= EmailStatusCode.rfc5322Domain;

                        parseData[EmailPart.componentDomain] ~= token;
                        atomList[EmailPart.componentDomain][elementCount] ~= token;
                        elementLength++;
                }
            break;

            case EmailPart.componentLiteral:
                switch (token)
                {
                    case Token.closeBracket:
                        if (returnStatus.max < EmailStatusCode.deprecated_)
                        {
                            auto maxGroups = 8;
                            size_t index = -1;
                            auto addressLiteral = parseData[EmailPart.componentLiteral];
                            enum regexStr = `\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}`~
                                            `(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$`;
                            auto matchesIp = array(addressLiteral.match(regex!tstring(regexStr)).captures);

                            if (!matchesIp.empty)
                            {
                                index = addressLiteral.lastIndexOf(matchesIp.front);

                                if (index != 0)
                                    addressLiteral = addressLiteral.substr(0, index) ~ "0:0";
                            }

                            if (index == 0)
                                returnStatus ~= EmailStatusCode.rfc5321AddressLiteral;

                            else if (addressLiteral.compareFirstN(Token.ipV6Tag, 5, true))
                                returnStatus ~= EmailStatusCode.rfc5322DomainLiteral;

                            else
                            {
                                auto ipV6 = addressLiteral.substr(5);
                                matchesIp = ipV6.split(Token.colon);
                                auto groupCount = matchesIp.length;
                                index = ipV6.indexOf(Token.doubleColon);

                                if (index == -1)
                                {
                                    if (groupCount != maxGroups)
                                        returnStatus ~= EmailStatusCode.rfc5322IpV6GroupCount;
                                }

                                else
                                {
                                    if (index != ipV6.lastIndexOf(Token.doubleColon))
                                        returnStatus ~= EmailStatusCode.rfc5322IpV6TooManyDoubleColons;

                                    else
                                    {
                                        if (index == 0 || index == (ipV6.length - 2))
                                            maxGroups++;

                                        if (groupCount > maxGroups)
                                            returnStatus ~= EmailStatusCode.rfc5322IpV6MaxGroups;

                                        else if (groupCount == maxGroups)
                                            returnStatus ~= EmailStatusCode.rfc5321IpV6Deprecated;
                                    }
                                }

                                if (ipV6.substr(0, 1) == Token.colon && ipV6.substr(1, 1) != Token.colon)
                                    returnStatus ~= EmailStatusCode.rfc5322IpV6ColonStart;

                                else if (ipV6.substr(-1) == Token.colon && ipV6.substr(-2, -1) != Token.colon)
                                    returnStatus ~= EmailStatusCode.rfc5322IpV6ColonEnd;

                                else if (!matchesIp.grep(regex!(tstring)(`^[0-9A-Fa-f]{0,4}$`), true).empty)
                                    returnStatus ~= EmailStatusCode.rfc5322IpV6BadChar;

                                else
                                    returnStatus ~= EmailStatusCode.rfc5321AddressLiteral;
                            }
                        }

                        else
                            returnStatus ~= EmailStatusCode.rfc5322DomainLiteral;

                        parseData[EmailPart.componentDomain] ~= token;
                        atomList[EmailPart.componentDomain][elementCount] ~= token;
                        elementLength++;
                        contextPrior = context;
                        context = contextStack.pop;
                    break;

                    case Token.backslash:
                        returnStatus ~= EmailStatusCode.rfc5322DomainLiteralObsoleteText;
                        contextStack ~= context;
                        context = EmailPart.contextQuotedPair;
                    break;

                    case Token.cr:
                    case Token.space:
                    case Token.tab:
                        if (token == Token.cr && (++i == email.length || email.get(i, e) != Token.lf))
                        {
                            returnStatus ~= EmailStatusCode.errorCrNoLf;
                            break;
                        }

                        returnStatus ~= EmailStatusCode.foldingWhitespace;
                        contextStack ~= context;
                        context = EmailPart.contextFoldingWhitespace;
                        tokenPrior = token;
                    break;

                    default:
                        auto c = token.front;

                        if (c > AsciiToken.delete_ || c == '\0' || token == Token.openBracket)
                        {
                            returnStatus ~= EmailStatusCode.errorExpectingDomainText;
                            break;
                        }

                        else if (c < '!' || c == AsciiToken.delete_ )
                            returnStatus ~= EmailStatusCode.rfc5322DomainLiteralObsoleteText;

                        parseData[EmailPart.componentLiteral] ~= token;
                        parseData[EmailPart.componentDomain] ~= token;
                        atomList[EmailPart.componentDomain][elementCount] ~= token;
                        elementLength++;
                }
            break;

            case EmailPart.contextQuotedString:
                switch (token)
                {
                    case Token.backslash:
                        contextStack ~= context;
                        context = EmailPart.contextQuotedPair;
                    break;

                    case Token.cr:
                    case Token.tab:
                        if (token == Token.cr && (++i == email.length || email.get(i, e) != Token.lf))
                        {
                            returnStatus ~= EmailStatusCode.errorCrNoLf;
                            break;
                        }

                        parseData[EmailPart.componentLocalPart] ~= Token.space;
                        atomList[EmailPart.componentLocalPart][elementCount] ~= Token.space;
                        elementLength++;

                        returnStatus ~= EmailStatusCode.foldingWhitespace;
                        contextStack ~= context;
                        context = EmailPart.contextFoldingWhitespace;
                        tokenPrior = token;
                    break;

                    case Token.doubleQuote:
                        parseData[EmailPart.componentLocalPart] ~= token;
                        atomList[EmailPart.componentLocalPart][elementCount] ~= token;
                        elementLength++;
                        contextPrior = context;
                        context = contextStack.pop;
                    break;

                    default:
                        auto c = token.front;

                        if (c > AsciiToken.delete_ || c == '\0' || c == '\n')
                            returnStatus ~= EmailStatusCode.errorExpectingQuotedText;

                        else if (c < ' ' || c == AsciiToken.delete_)
                            returnStatus ~= EmailStatusCode.deprecatedQuotedText;

                        parseData[EmailPart.componentLocalPart] ~= token;
                        atomList[EmailPart.componentLocalPart][elementCount] ~= token;
                        elementLength++;
                }
            break;

            case EmailPart.contextQuotedPair:
                auto c = token.front;

                if (c > AsciiToken.delete_)
                    returnStatus ~= EmailStatusCode.errorExpectingQuotedPair;

                else if (c < AsciiToken.unitSeparator && c != AsciiToken.horizontalTab || c == AsciiToken.delete_)
                    returnStatus ~= EmailStatusCode.deprecatedQuotedPair;

                contextPrior = context;
                context = contextStack.pop;
                token = Token.backslash ~ token;

                switch (context)
                {
                    case EmailPart.contextComment: break;

                    case EmailPart.contextQuotedString:
                        parseData[EmailPart.componentLocalPart] ~= token;
                        atomList[EmailPart.componentLocalPart][elementCount] ~= token;
                        elementLength += 2;
                    break;

                    case EmailPart.componentLiteral:
                        parseData[EmailPart.componentDomain] ~= token;
                        atomList[EmailPart.componentDomain][elementCount] ~= token;
                        elementLength += 2;
                    break;

                    default:
                        throw new Exception("Quoted pair logic invoked in an invalid context: " ~ to!(string)(context));
                }
            break;

            case EmailPart.contextComment:
                switch (token)
                {
                    case Token.openParenthesis:
                        contextStack ~= context;
                        context = EmailPart.contextComment;
                    break;

                    case Token.closeParenthesis:
                        contextPrior = context;
                        context = contextStack.pop;
                    break;

                    case Token.backslash:
                        contextStack ~= context;
                        context = EmailPart.contextQuotedPair;
                    break;

                    case Token.cr:
                    case Token.space:
                    case Token.tab:
                        if (token == Token.cr && (++i == email.length || email.get(i, e) != Token.lf))
                        {
                            returnStatus ~= EmailStatusCode.errorCrNoLf;
                            break;
                        }

                        returnStatus ~= EmailStatusCode.foldingWhitespace;

                        contextStack ~= context;
                        context = EmailPart.contextFoldingWhitespace;
                        tokenPrior = token;
                    break;

                    default:
                        auto c = token.front;

                        if (c > AsciiToken.delete_ || c == '\0' || c == '\n')
                        {
                            returnStatus ~= EmailStatusCode.errorExpectingCommentText;
                            break;
                        }

                        else if (c < ' ' || c == AsciiToken.delete_)
                            returnStatus ~= EmailStatusCode.deprecatedCommentText;
                }
            break;

            case EmailPart.contextFoldingWhitespace:
                if (tokenPrior == Token.cr)
                {
                    if (token == Token.cr)
                    {
                        returnStatus ~= EmailStatusCode.errorFoldingWhitespaceCrflX2;
                        break;
                    }

                    if (crlfCount != int.min) // int.min == not defined
                    {
                        if (++crlfCount > 1)
                            returnStatus ~= EmailStatusCode.deprecatedFoldingWhitespace;
                    }

                    else
                        crlfCount = 1;
                }

                switch (token)
                {
                    case Token.cr:
                        if (++i == email.length || email.get(i, e) != Token.lf)
                            returnStatus ~= EmailStatusCode.errorCrNoLf;
                    break;

                    case Token.space:
                    case Token.tab:
                    break;

                    default:
                        if (tokenPrior == Token.cr)
                        {
                            returnStatus ~= EmailStatusCode.errorFoldingWhitespaceCrLfEnd;
                            break;
                        }

                        crlfCount = int.min; // int.min == not defined
                        contextPrior = context;
                        context = contextStack.pop;
                        i--;
                    break;
                }

                tokenPrior = token;
            break;

            default:
                throw new Exception("Unkown context: " ~ to!(string)(context));
        }

        if (returnStatus.max > EmailStatusCode.rfc5322)
            break;
    }

    if (returnStatus.max < EmailStatusCode.rfc5322)
    {
        if (context == EmailPart.contextQuotedString)
            returnStatus ~= EmailStatusCode.errorUnclosedQuotedString;

        else if (context == EmailPart.contextQuotedPair)
            returnStatus ~= EmailStatusCode.errorBackslashEnd;

        else if (context == EmailPart.contextComment)
            returnStatus ~= EmailStatusCode.errorUnclosedComment;

        else if (context == EmailPart.componentLiteral)
            returnStatus ~= EmailStatusCode.errorUnclosedDomainLiteral;

        else if (token == Token.cr)
            returnStatus ~= EmailStatusCode.errorFoldingWhitespaceCrLfEnd;

        else if (parseData[EmailPart.componentDomain] == "")
            returnStatus ~= EmailStatusCode.errorNoDomain;

        else if (elementLength == 0)
            returnStatus ~= EmailStatusCode.errorDotEnd;

        else if (hyphenFlag)
            returnStatus ~= EmailStatusCode.errorDomainHyphenEnd;

        else if (parseData[EmailPart.componentDomain].length > 255)
            returnStatus ~= EmailStatusCode.rfc5322DomainTooLong;

        else if ((parseData[EmailPart.componentLocalPart] ~ Token.at ~ parseData[EmailPart.componentDomain]).length >
            254)
                returnStatus ~= EmailStatusCode.rfc5322TooLong;

        else if (elementLength > 63)
            returnStatus ~= EmailStatusCode.rfc5322LabelTooLong;
    }

    auto dnsChecked = false;

    if (checkDNS == CheckDns.yes && returnStatus.max < EmailStatusCode.dnsWarning)
    {
        assert(false, "DNS check is currently not implemented");
    }

    if (!dnsChecked && returnStatus.max < EmailStatusCode.dnsWarning)
    {
        if (elementCount == 0)
            returnStatus ~= EmailStatusCode.rfc5321TopLevelDomain;

        if (isNumeric(atomList[EmailPart.componentDomain][elementCount].front))
            returnStatus ~= EmailStatusCode.rfc5321TopLevelDomainNumeric;
    }

    returnStatus = array(std.algorithm.uniq(returnStatus));
    auto finalStatus = returnStatus.max;

    if (returnStatus.length != 1)
        returnStatus.popFront;

    parseData[EmailPart.status] = to!(tstring)(returnStatus);

    if (finalStatus < threshold)
        finalStatus = EmailStatusCode.valid;

    if (!diagnose)
        finalStatus = finalStatus < threshold ? EmailStatusCode.valid : EmailStatusCode.error;

    auto valid = finalStatus == EmailStatusCode.valid;
    tstring localPart = "";
    tstring domainPart = "";

    if (auto value = EmailPart.componentLocalPart in parseData)
        localPart = *value;

    if (auto value = EmailPart.componentDomain in parseData)
        domainPart = *value;

    return EmailStatus(valid, to!(string)(localPart), to!(string)(domainPart), finalStatus);
}

unittest
{
    assert(``.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoDomain);
    assert(`test`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoDomain);
    assert(`@`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoLocalPart);
    assert(`test@`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoDomain);

    // assert(`test@io`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid,
    //     `io. currently has an MX-record (Feb 2011). Some DNS setups seem to find it, some don't.`
    //     ` If you don't see the MX for io. then try setting your DNS server to 8.8.8.8 (the Google DNS server)`);

    assert(`@io`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoLocalPart,
        `io. currently has an MX-record (Feb 2011)`);

    assert(`@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoLocalPart);
    assert(`test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);
    assert(`test@nominet.org.uk`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);
    assert(`test@about.museum`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);
    assert(`a@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);

    //assert(`test@e.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.dnsWarningNoRecord);
        // DNS check is currently not implemented

    //assert(`test@iana.a`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.dnsWarningNoRecord);
        // DNS check is currently not implemented

    assert(`test.test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);
    assert(`.test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorDotStart);
    assert(`test.@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorDotEnd);

    assert(`test..iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorConsecutiveDots);

    assert(`test_exa-mple.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorNoDomain);
    assert("!#$%&`*+/=?^`{|}~@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);

    assert(`test\@test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert(`123@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);
    assert(`test@123.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);

    assert(`test@iana.123`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.rfc5321TopLevelDomainNumeric);
    assert(`test@255.255.255.255`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.rfc5321TopLevelDomainNumeric);

    assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@iana.org`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.valid);

    assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklmn@iana.org`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322LocalTooLong);

    // assert(`test@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.com`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.dnsWarningNoRecord);
        // DNS check is currently not implemented

    assert(`test@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm.com`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322LabelTooLong);

    assert(`test@mason-dixon.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);

    assert(`test@-iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorDomainHyphenStart);

    assert(`test@iana-.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorDomainHyphenEnd);

    assert(`test@g--a.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid);

    //assert(`test@iana.co-uk`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        //EmailStatusCode.dnsWarningNoRecord); // DNS check is currently not implemented

    assert(`test@.iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorDotStart);
    assert(`test@iana.org.`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorDotEnd);
    assert(`test@iana..com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorConsecutiveDots);

    //assert(`a@a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z`
    //        `.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z`
    //        `.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //        EmailStatusCode.dnsWarningNoRecord); // DNS check is currently not implemented

    // assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@abcdefghijklmnopqrstuvwxyz`
    //         `abcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.`
    //         `abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghi`.isEmail(CheckDns.no,
    //         EmailStatusCode.any).statusCode == EmailStatusCode.dnsWarningNoRecord);
        // DNS check is currently not implemented

    assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@abcdefghijklmnopqrstuvwxyz`
        `abcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.`
        `abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghij`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322TooLong);

    assert(`a@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyz`
        `abcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.`
        `abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefg.hij`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322TooLong);

    assert(`a@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyz`
        `abcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.`
        `abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefg.hijk`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322DomainTooLong);

    assert(`"test"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.rfc5321QuotedString);

    assert(`""@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321QuotedString);
    assert(`"""@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorExpectingText);
    assert(`"\a"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321QuotedString);
    assert(`"\""@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321QuotedString);

    assert(`"\"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedQuotedString);

    assert(`"\\"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321QuotedString);
    assert(`test"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorExpectingText);

    assert(`"test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedQuotedString);

    assert(`"test"test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorTextAfterQuotedString);

    assert(`test"text"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert(`"test""test"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert(`"test"."test"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedLocalPart);

    assert(`"test\ test"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.rfc5321QuotedString);

    assert(`"test".test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedLocalPart);

    assert("\"test\u0000\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingQuotedText);

    assert("\"test\\\u0000\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedQuotedPair);

    assert(`"abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz abcdefghj"@iana.org`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322LocalTooLong,
        `Quotes are still part of the length restriction`);

    assert(`"abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz abcdefg\h"@iana.org`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322LocalTooLong,
        `Quoted pair is still part of the length restriction`);

    // assert(`test@[255.255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom

    // assert(`test@a[255.255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.errorExpectingText);
    //
    // assert(`test@[255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[255.255.255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[255.255.255.256]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[1111:2222:3333:4444:5555:6666:7777:8888]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322IpV6GroupCount); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:8888]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode
    //     == EmailStatusCode.rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:8888:9999]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322IpV6GroupCount);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:888G]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322IpV6BadChar);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666::8888]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321IpV6Deprecated);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555::8888]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666::7777:8888]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322IpV6MaxGroups);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6::3333:4444:5555:6666:7777:8888]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322IpV6ColonStart); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:::3333:4444:5555:6666:7777:8888]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111::4444:5555::8888]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322IpV6TooManyDoubleColons); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:::]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:255.255.255.255]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322IpV6GroupCount);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:255.255.255.255]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321AddressLiteral);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:255.255.255.255]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322IpV6GroupCount);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444::255.255.255.255]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321AddressLiteral);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:5555:6666::255.255.255.255]`.isEmail(CheckDns.no,
    //     EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322IpV6MaxGroups);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6:1111:2222:3333:4444:::255.255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode
    //     == EmailStatusCode.rfc5322IpV6TooManyDoubleColons); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[IPv6::255.255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322IpV6ColonStart); // std.regex bug: *+? not allowed in atom

    assert(` test @iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt);

    assert(`test@ iana .com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt);

    assert(`test . test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedFoldingWhitespace);

    assert("\u000D\u000A test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.foldingWhitespace, `Folding whitespace`);

    assert("\u000D\u000A \u000D\u000A test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedFoldingWhitespace, `FWS with one line composed entirely of WSP`
        ` -- only allowed as obsolete FWS (someone might allow only non-obsolete FWS)`);

    assert(`(comment)test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.comment);
    assert(`((comment)test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedComment);

    assert(`(comment(comment))test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.comment);

    assert(`test@(comment)iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt);

    assert(`test(comment)test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorTextAfterCommentFoldingWhitespace);

    // assert(`test@(comment)[255.255.255.255]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt); // std.regex bug: *+? not allowed in atom

    assert(`(comment)abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@iana.org`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.comment);

    assert(`test@(comment)abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.com`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt);

    assert(`(comment)test@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghik.abcdefghijklmnopqrstuvwxyz`
        `abcdefghijklmnopqrstuvwxyzabcdefghik.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk.`
        `abcdefghijklmnopqrstuvwxyzabcdefghijk.abcdefghijklmnopqrstu`.isEmail(CheckDns.no,
        EmailStatusCode.any).statusCode == EmailStatusCode.comment);

    assert("test@iana.org\u000A".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert(`test@xn--hxajbheg2az3al.xn--jxalpdlp`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.valid, `A valid IDN from ICANN's <a href="http://idn.icann.org/#The_example.test_names">`
        `IDN TLD evaluation gateway</a>`);

    assert(`xn--test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.valid,
        `RFC 3490: "unless the email standards are revised to invite the use of IDNA for local parts, a domain label`
        ` that holds the local part of an email address SHOULD NOT begin with the ACE prefix, and even if it does,`
        ` it is to be interpreted literally as a local part that happens to begin with the ACE prefix"`);

    assert(`test@iana.org-`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorDomainHyphenEnd);

    assert(`"test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedQuotedString);

    assert(`(test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedComment);

    assert(`test@(iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedComment);

    assert(`test@[1.2.3.4`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedDomainLiteral);

    assert(`"test\"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedQuotedString);

    assert(`(comment\)test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedComment);

    assert(`test@iana.org(comment\)`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorUnclosedComment);

    assert(`test@iana.org(comment\`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorBackslashEnd);

    // assert(`test@[RFC-5322-domain-literal]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC-5322]-domain-literal]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.errorTextAfterDomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC-5322-[domain-literal]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.errorExpectingDomainText); // std.regex bug: *+? not allowed in atom
    //
    // assert("test@[RFC-5322-\\\u0007-domain-literal]".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteralObsoleteText, `obs-dtext <strong>and</strong> obs-qp`);
        // std.regex bug: *+? not allowed in atom
    //
    // assert("test@[RFC-5322-\\\u0009-domain-literal]".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteralObsoleteText); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC-5322-\]-domain-literal]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteralObsoleteText); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC-5322-domain-literal\]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.errorUnclosedDomainLiteral); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC-5322-domain-literal\`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.errorBackslashEnd); // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC 5322 domain literal]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral, `Spaces are FWS in a domain literal`);
        // std.regex bug: *+? not allowed in atom
    //
    // assert(`test@[RFC-5322-domain-literal] (comment)`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom

    assert(`@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorExpectingText);
    assert(`test@.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorExpectingText);
    assert(`""@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.deprecatedQuotedText);

    assert(`"\"@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
            EmailStatusCode.deprecatedQuotedPair);

    assert(`()test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedCommentText);

    assert("test@iana.org\u000D".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorCrNoLf,
        `No LF after the CR`);

    assert("\u000Dtest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorCrNoLf,
        `No LF after the CR`);

    assert("\"\u000Dtest\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorCrNoLf
        ,`No LF after the CR`);

    assert("(\u000D)test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorCrNoLf,
        `No LF after the CR`);

    assert("(\u000D".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorCrNoLf,
        `No LF after the CR`);

    assert("test@iana.org(\u000D)".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.errorCrNoLf,
        `No LF after the CR`);

    assert("\u000Atest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert("\"\u000A\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingQuotedText);

    assert("\"\\\u000A\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedQuotedPair);

    assert("(\u000A)test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingCommentText);

    assert("\u0007@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert("test@\u0007.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingText);

    assert("\"\u0007\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedQuotedText);

    assert("\"\\\u0007\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedQuotedPair);

    assert("(\u0007)test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedCommentText);

    assert("\u000D\u000Atest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not FWS because no actual white space`);

    assert("\u000D\u000A \u000D\u000Atest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not obs-FWS because there must be white space on each "fold"`);

    assert(" \u000D\u000Atest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the fold`);

    assert(" \u000D\u000A test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.foldingWhitespace, `FWS`);

    assert(" \u000D\u000A \u000D\u000Atest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the second fold`);

    assert(" \u000D\u000A\u000D\u000Atest@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrflX2, `Not FWS because no white space after either fold`);

    assert(" \u000D\u000A\u000D\u000A test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrflX2, `Not FWS because no white space after the first fold`);

    assert("test@iana.org\u000D\u000A ".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.foldingWhitespace, `FWS`);

    assert("test@iana.org\u000D\u000A \u000D\u000A ".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedFoldingWhitespace, `FWS with one line composed entirely of WSP -- `
        `only allowed as obsolete FWS (someone might allow only non-obsolete FWS)`);

    assert("test@iana.org\u000D\u000A".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not FWS because no actual white space`);

    assert("test@iana.org\u000D\u000A \u000D\u000A".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not obs-FWS because there must be white space on each "fold"`);

    assert("test@iana.org \u000D\u000A".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the fold`);

    assert("test@iana.org \u000D\u000A ".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.foldingWhitespace, `FWS`);

    assert("test@iana.org \u000D\u000A \u000D\u000A".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the second fold`);

    assert("test@iana.org \u000D\u000A\u000D\u000A".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrflX2, `Not FWS because no white space after either fold`);

    assert("test@iana.org \u000D\u000A\u000D\u000A ".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorFoldingWhitespaceCrflX2, `Not FWS because no white space after the first fold`);

    assert(" test@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.foldingWhitespace);
    assert(`test@iana.org `.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.foldingWhitespace);

    // assert(`test@[IPv6:1::2:]`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
    //     EmailStatusCode.rfc5322IpV6ColonEnd); // std.regex bug: *+? not allowed in atom

    assert("\"test\\\u00A9\"@iana.org".isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.errorExpectingQuotedPair);

    assert(`test@iana/icann.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.rfc5322Domain);

    assert(`test.(comment)test@iana.org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
        EmailStatusCode.deprecatedComment);

    assert(`test@org`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.rfc5321TopLevelDomain);

    // assert(`test@test.com`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode ==
            //EmailStatusCode.dnsWarningNoMXRecord, `test.com has an A-record but not an MX-record`);
            // DNS check is currently not implemented
    //
    // assert(`test@nic.no`.isEmail(CheckDns.no, EmailStatusCode.any).statusCode == EmailStatusCode.dnsWarningNoRecord,
    //     `nic.no currently has no MX-records or A-records (Feb 2011). If you are seeing an A-record for nic.io then`
    //       ` try setting your DNS server to 8.8.8.8 (the Google DNS server) - your DNS server may be faking an A-record`
    //     ` (OpenDNS does this, for instance).`); // DNS check is currently not implemented
}

/// Enum for indicating if the isEmail function should perform a DNS check or not.
enum CheckDns
{
    /// Does not perform DNS checking
    no,

    /// Performs DNS checking
    yes
}

/// This struct represents the status of an email address
struct EmailStatus
{
    private
    {
        bool valid_;
        string localPart_;
        string domainPart_;
        EmailStatusCode statusCode_;
    }

    ///
    alias valid this;

    /*
     * Params:
     *     valid = indicates if the email address is valid or not
     *     localPart = the local part of the email address
     *     domainPart = the domain part of the email address
     *        statusCode = the status code
     */
    private this (bool valid, string localPart, string domainPart, EmailStatusCode statusCode)
    {
        this.valid_ = valid;
        this.localPart_ = localPart;
        this.domainPart_ = domainPart;
        this.statusCode_ = statusCode;
    }

    /// Indicates if the email address is valid or not.
    bool valid ()
    {
        return valid_;
    }

    /// The local part of the email address, that is, the part before the @ sign.
    string localPart ()
    {
        return localPart_;
    }

    /// The domain part of the email address, that is, the part after the @ sign.
    string domainPart ()
    {
        return domainPart_;
    }

    /// The email status code
    EmailStatusCode statusCode ()
    {
        return statusCode_;
    }

    /// Returns a describing string of the status code
    string status ()
    {
        return statusCodeDescription(statusCode_);
    }

    /// Returns a textual representation of the email status
    string toString ()
    {
        return format("EmailStatus\n{\n\tvalid: %s\n\tlocalPart: %s\n\tdomainPart: %s\n\tstatusCode: %s\n}", valid,
            localPart, domainPart, statusCode);
    }
}

/// Returns a describing string of the given status code
string statusCodeDescription (EmailStatusCode statusCode)
{
    final switch (statusCode)
    {
        // Categories
        case EmailStatusCode.validCategory: return "Address is valid";
        case EmailStatusCode.dnsWarning: return "Address is valid but a DNS check was not successful";
        case EmailStatusCode.rfc5321: return "Address is valid for SMTP but has unusual elements";

        case EmailStatusCode.cFoldingWhitespace: return "Address is valid within the message but cannot be used"
            " unmodified for the envelope";

        case EmailStatusCode.deprecated_: return "Address contains deprecated elements but may still be valid in"
            " restricted contexts";

        case EmailStatusCode.rfc5322: return "The address is only valid according to the broad definition of RFC 5322."
            " It is otherwise invalid";

        case EmailStatusCode.any: return "";
        case EmailStatusCode.none: return "";
        case EmailStatusCode.warning: return "";
        case EmailStatusCode.error: return "Address is invalid for any purpose";

        // Diagnoses
        case EmailStatusCode.valid: return "Address is valid";

        // Address is valid but a DNS check was not successful
        case EmailStatusCode.dnsWarningNoMXRecord: return "Could not find an MX record for this domain but an A-record"
            " does exist";

        case EmailStatusCode.dnsWarningNoRecord: return "Could not find an MX record or an A-record for this domain";

        // Address is valid for SMTP but has unusual elements
        case EmailStatusCode.rfc5321TopLevelDomain: return "Address is valid but at a Top Level Domain";

        case EmailStatusCode.rfc5321TopLevelDomainNumeric: return "Address is valid but the Top Level Domain begins"
            " with a number";

        case EmailStatusCode.rfc5321QuotedString: return "Address is valid but contains a quoted string";
        case EmailStatusCode.rfc5321AddressLiteral: return "Address is valid but at a literal address not a domain";

        case EmailStatusCode.rfc5321IpV6Deprecated: return "Address is valid but contains a :: that only elides one"
            " zero group";


        // Address is valid within the message but cannot be used unmodified for the envelope
        case EmailStatusCode.comment: return "Address contains comments";
        case EmailStatusCode.foldingWhitespace: return "Address contains Folding White Space";

        // Address contains deprecated elements but may still be valid in restricted contexts
        case EmailStatusCode.deprecatedLocalPart: return "The local part is in a deprecated form";

        case EmailStatusCode.deprecatedFoldingWhitespace: return "Address contains an obsolete form of"
            " Folding White Space";

        case EmailStatusCode.deprecatedQuotedText: return "A quoted string contains a deprecated character";
        case EmailStatusCode.deprecatedQuotedPair: return "A quoted pair contains a deprecated character";
        case EmailStatusCode.deprecatedComment: return "Address contains a comment in a position that is deprecated";
        case EmailStatusCode.deprecatedCommentText: return "A comment contains a deprecated character";

        case EmailStatusCode.deprecatedCommentFoldingWhitespaceNearAt: return "Address contains a comment or"
            " Folding White Space around the @ sign";

        // The address is only valid according to the broad definition of RFC 5322
        case EmailStatusCode.rfc5322Domain: return "Address is RFC 5322 compliant but contains domain characters that"
        " are not allowed by DNS";

        case EmailStatusCode.rfc5322TooLong: return "Address is too long";
        case EmailStatusCode.rfc5322LocalTooLong: return "The local part of the address is too long";
        case EmailStatusCode.rfc5322DomainTooLong: return "The domain part is too long";
        case EmailStatusCode.rfc5322LabelTooLong: return "The domain part contains an element that is too long";
        case EmailStatusCode.rfc5322DomainLiteral: return "The domain literal is not a valid RFC 5321 address literal";

        case EmailStatusCode.rfc5322DomainLiteralObsoleteText: return "The domain literal is not a valid RFC 5321"
            " address literal and it contains obsolete characters";

        case EmailStatusCode.rfc5322IpV6GroupCount:
            return "The IPv6 literal address contains the wrong number of groups";

        case EmailStatusCode.rfc5322IpV6TooManyDoubleColons:
            return "The IPv6 literal address contains too many :: sequences";

        case EmailStatusCode.rfc5322IpV6BadChar: return "The IPv6 address contains an illegal group of characters";
        case EmailStatusCode.rfc5322IpV6MaxGroups: return "The IPv6 address has too many groups";
        case EmailStatusCode.rfc5322IpV6ColonStart: return "IPv6 address starts with a single colon";
        case EmailStatusCode.rfc5322IpV6ColonEnd: return "IPv6 address ends with a single colon";

        // Address is invalid for any purpose
        case EmailStatusCode.errorExpectingDomainText:
            return "A domain literal contains a character that is not allowed";

        case EmailStatusCode.errorNoLocalPart: return "Address has no local part";
        case EmailStatusCode.errorNoDomain: return "Address has no domain part";
        case EmailStatusCode.errorConsecutiveDots: return "The address may not contain consecutive dots";

        case EmailStatusCode.errorTextAfterCommentFoldingWhitespace:
            return "Address contains text after a comment or Folding White Space";

        case EmailStatusCode.errorTextAfterQuotedString: return "Address contains text after a quoted string";

        case EmailStatusCode.errorTextAfterDomainLiteral: return "Extra characters were found after the end of"
            " the domain literal";

        case EmailStatusCode.errorExpectingQuotedPair:
            return "The address contains a character that is not allowed in a quoted pair";

        case EmailStatusCode.errorExpectingText: return "Address contains a character that is not allowed";

        case EmailStatusCode.errorExpectingQuotedText:
            return "A quoted string contains a character that is not allowed";

        case EmailStatusCode.errorExpectingCommentText: return "A comment contains a character that is not allowed";
        case EmailStatusCode.errorBackslashEnd: return "The address cannot end with a backslash";
        case EmailStatusCode.errorDotStart: return "Neither part of the address may begin with a dot";
        case EmailStatusCode.errorDotEnd: return "Neither part of the address may end with a dot";
        case EmailStatusCode.errorDomainHyphenStart: return "A domain or subdomain cannot begin with a hyphen";
        case EmailStatusCode.errorDomainHyphenEnd: return "A domain or subdomain cannot end with a hyphen";
        case EmailStatusCode.errorUnclosedQuotedString: return "Unclosed quoted string";
        case EmailStatusCode.errorUnclosedComment: return "Unclosed comment";
        case EmailStatusCode.errorUnclosedDomainLiteral: return "Domain literal is missing its closing bracket";

        case EmailStatusCode.errorFoldingWhitespaceCrflX2:
            return "Folding White Space contains consecutive CRLF sequences";

        case EmailStatusCode.errorFoldingWhitespaceCrLfEnd: return "Folding White Space ends with a CRLF sequence";

        case EmailStatusCode.errorCrNoLf:
            return "Address contains a carriage return that is not followed by a line feed";
    }
}

/**
 * An email status code, indicating if an email address is valid or not.
 * If it is invalid it also indicates why.
 */
enum EmailStatusCode
{
    // Categories

    /// Address is valid
    validCategory = 1,

    /// Address is valid but a DNS check was not successful
    dnsWarning = 7,

    /// Address is valid for SMTP but has unusual elements
    rfc5321 = 15,

    /// Address is valid within the message but cannot be used unmodified for the envelope
    cFoldingWhitespace = 31,

    /// Address contains deprecated elements but may still be valid in restricted contexts
    deprecated_ = 63,

    /// The address is only valid according to the broad definition of RFC 5322. It is otherwise invalid
    rfc5322 = 127,

    /**
     * All finer grained error checking is turned on. Address containing errors or
     * warnings is considered invalid. A specific email status code will be
     * returned indicating the error/warning of the address.
     */
    any = 252,

    /**
     * Address is either considered valid or not, no finer grained error checking
     * is performed. Returned email status code will be either Error or Valid.
     */
    none = 253,

    /**
     * Address containing warnings is considered valid, that is,
     * any status code below 16 is considered valid.
     */
    warning = 254,

    /// Address is invalid for any purpose
    error = 255,



    // Diagnoses

    /// Address is valid
    valid = 0,

    // Address is valid but a DNS check was not successful

    /// Could not find an MX record for this domain but an A-record does exist
    dnsWarningNoMXRecord = 5,

    /// Could not find an MX record or an A-record for this domain
    dnsWarningNoRecord = 6,



    // Address is valid for SMTP but has unusual elements

    /// Address is valid but at a Top Level Domain
    rfc5321TopLevelDomain = 9,

    /// Address is valid but the Top Level Domain begins with a number
    rfc5321TopLevelDomainNumeric = 10,

    /// Address is valid but contains a quoted string
    rfc5321QuotedString = 11,

    /// Address is valid but at a literal address not a domain
    rfc5321AddressLiteral = 12,

    /// Address is valid but contains a :: that only elides one zero group
    rfc5321IpV6Deprecated = 13,



    // Address is valid within the message but cannot be used unmodified for the envelope

    /// Address contains comments
    comment = 17,

    /// Address contains Folding White Space
    foldingWhitespace = 18,



    // Address contains deprecated elements but may still be valid in restricted contexts

    /// The local part is in a deprecated form
    deprecatedLocalPart = 33,

    /// Address contains an obsolete form of Folding White Space
    deprecatedFoldingWhitespace = 34,

    /// A quoted string contains a deprecated character
    deprecatedQuotedText = 35,

    /// A quoted pair contains a deprecated character
    deprecatedQuotedPair = 36,

    /// Address contains a comment in a position that is deprecated
    deprecatedComment = 37,

    /// A comment contains a deprecated character
    deprecatedCommentText = 38,

    /// Address contains a comment or Folding White Space around the @ sign
    deprecatedCommentFoldingWhitespaceNearAt = 49,



    // The address is only valid according to the broad definition of RFC 5322

    /// Address is RFC 5322 compliant but contains domain characters that are not allowed by DNS
    rfc5322Domain = 65,

    /// Address is too long
    rfc5322TooLong = 66,

    /// The local part of the address is too long
    rfc5322LocalTooLong = 67,

    /// The domain part is too long
    rfc5322DomainTooLong = 68,

    /// The domain part contains an element that is too long
    rfc5322LabelTooLong = 69,

    /// The domain literal is not a valid RFC 5321 address literal
    rfc5322DomainLiteral = 70,

    /// The domain literal is not a valid RFC 5321 address literal and it contains obsolete characters
    rfc5322DomainLiteralObsoleteText = 71,

    /// The IPv6 literal address contains the wrong number of groups
    rfc5322IpV6GroupCount = 72,

    /// The IPv6 literal address contains too many :: sequences
    rfc5322IpV6TooManyDoubleColons = 73,

    /// The IPv6 address contains an illegal group of characters
    rfc5322IpV6BadChar = 74,

    /// The IPv6 address has too many groups
    rfc5322IpV6MaxGroups = 75,

    /// IPv6 address starts with a single colon
    rfc5322IpV6ColonStart = 76,

    /// IPv6 address ends with a single colon
    rfc5322IpV6ColonEnd = 77,



    // Address is invalid for any purpose

    /// A domain literal contains a character that is not allowed
    errorExpectingDomainText = 129,

    /// Address has no local part
    errorNoLocalPart = 130,

    /// Address has no domain part
    errorNoDomain = 131,

    /// The address may not contain consecutive dots
    errorConsecutiveDots = 132,

    /// Address contains text after a comment or Folding White Space
    errorTextAfterCommentFoldingWhitespace = 133,

    /// Address contains text after a quoted string
    errorTextAfterQuotedString = 134,

    /// Extra characters were found after the end of the domain literal
    errorTextAfterDomainLiteral = 135,

    /// The address contains a character that is not allowed in a quoted pair
    errorExpectingQuotedPair = 136,

    /// Address contains a character that is not allowed
    errorExpectingText = 137,

    /// A quoted string contains a character that is not allowed
    errorExpectingQuotedText = 138,

    /// A comment contains a character that is not allowed
    errorExpectingCommentText = 139,

    /// The address cannot end with a backslash
    errorBackslashEnd = 140,

    /// Neither part of the address may begin with a dot
    errorDotStart = 141,

    /// Neither part of the address may end with a dot
    errorDotEnd = 142,

    /// A domain or subdomain cannot begin with a hyphen
    errorDomainHyphenStart = 143,

    /// A domain or subdomain cannot end with a hyphen
    errorDomainHyphenEnd = 144,

    /// Unclosed quoted string
    errorUnclosedQuotedString = 145,

    /// Unclosed comment
    errorUnclosedComment = 146,

    /// Domain literal is missing its closing bracket
    errorUnclosedDomainLiteral = 147,

    /// Folding White Space contains consecutive CRLF sequences
    errorFoldingWhitespaceCrflX2 = 148,

    /// Folding White Space ends with a CRLF sequence
    errorFoldingWhitespaceCrLfEnd = 149,

    /// Address contains a carriage return that is not followed by a line feed
    errorCrNoLf = 150,
}

private:

enum threshold = 16;

// Email parts for the isEmail function
enum EmailPart
{
    // The local part of the email address, that is, the part before the @ sign
    componentLocalPart,

    // The domain part of the email address, that is, the part after the @ sign.
    componentDomain,

    componentLiteral,
    contextComment,
    contextFoldingWhitespace,
    contextQuotedString,
    contextQuotedPair,
    status
}

// Miscellaneous string constants
struct Token
{
    enum
    {
        at = "@",
        backslash = `\`,
        dot = ".",
        doubleQuote = `"`,
        openParenthesis = "(",
        closeParenthesis = ")",
        openBracket = "[",
        closeBracket = "]",
        hyphen = "-",
        colon = ":",
        doubleColon = "::",
        space = " ",
        tab = "\t",
        cr = "\r",
        lf = "\n",
        ipV6Tag = "IPV6:",

        // US-ASCII visible characters not valid for atext (http://tools.ietf.org/html/rfc5322#section-3.2.3)
        specials = `()<>[]:;@\\,."`
    }
}

enum AsciiToken
{
    horizontalTab = 9,
    unitSeparator = 31,
    delete_ = 127
}

/*
 * Returns the maximum of the values in the given array.
 *
 * Examples:
 * ---
 * assert([1, 2, 3, 4].max == 4);
 * assert([3, 5, 9, 2, 5].max == 9);
 * assert([7, 13, 9, 12, 0].max == 13);
 * ---
 *
 * Params:
 *     arr = the array containing the values to return the maximum of
 *
 * Returns: the maximum value
 */
T max (T) (T[] arr)
{
    auto max = arr.front;

    foreach (i ; 0 .. arr.length - 1)
        max = std.algorithm.max(max, arr[i + 1]);

    return max;
}

unittest
{
    assert([1, 2, 3, 4].max == 4);
    assert([3, 5, 9, 2, 5].max == 9);
    assert([7, 13, 9, 12, 0].max == 13);
}

/*
 * Returns the portion of string specified by the $(D_PARAM start) and
 * $(D_PARAM length) parameters.
 *
 * Examples:
 * ---
 * assert("abcdef".substr(-1) == "f");
 * assert("abcdef".substr(-2) == "ef");
 * assert("abcdef".substr(-3, 1) == "d");
 * ---
 *
 * Params:
 *     str = the input string. Must be one character or longer.
 *     start = if $(D_PARAM start) is non-negative, the returned string will start at the
 *             $(D_PARAM start)'th position in $(D_PARAM str), counting from zero.
 *             For instance, in the string "abcdef", the character at position 0 is 'a',
 *             the character at position 2 is 'c', and so forth.
 *
 *             If $(D_PARAM start) is negative, the returned string will start at the
 *             $(D_PARAM start)'th character from the end of $(D_PARAM str).
 *
 *             If $(D_PARAM str) is less than or equal to $(D_PARAM start) characters long,
 *             $(D_KEYWORD true) will be returned.
 *
 *     length = if $(D_PARAM length) is given and is positive, the string returned will
 *              contain at most $(D_PARAM length) characters beginning from $(D_PARAM start)
 *              (depending on the length of string).
 *
 *              If $(D_PARAM length) is given and is negative, then that many characters
 *              will be omitted from the end of string (after the start position has been
 *              calculated when a $(D_PARAM start) is negative). If $(D_PARAM start)
 *              denotes the position of this truncation or beyond, $(D_KEYWORD false)
 *              will be returned.
 *
 *              If $(D_PARAM length) is given and is 0, an empty string will be returned.
 *
 *              If $(D_PARAM length) is omitted, the substring starting from $(D_PARAM start)
 *              until the end of the string will be returned.
 *
 * Returns: the extracted part of string, or an empty string.
 */
T[] substr (T) (T[] str, sizediff_t start = 0, sizediff_t length = sizediff_t.min)
{
    sizediff_t end = length;

    if (start < 0)
    {
        start = str.length + start;

        if (end < 0)
        {
            if (end == sizediff_t.min)
                end = 0;

            end = str.length + end;
        }


        else
            end = start + end;
    }

    else
    {
        if (end == sizediff_t.min)
            end = str.length;

        if (end < 0)
            end = str.length + end;
    }

    if (start > end)
        end = start;

    return str[start .. end];
}

unittest
{
    assert("abcdef".substr(-1) == "f");
    assert("abcdef".substr(-2) == "ef");
    assert("abcdef".substr(-3, 1) == "d");
    assert("abcdef".substr(0, -1) == "abcde");
    assert("abcdef".substr(2, -1) == "cde");
    assert("abcdef".substr(4, -4) == []);
    assert("abcdef".substr(-3, -1) == "de");
}

/*
 * Compare the two given strings lexicographically. An upper limit of the number of
 * characters, that will be used in the comparison, can be specified. Supports both
 * case-sensitive and case-insensitive comparison.
 *
 * Examples:
 * ---
 * assert("abc".compareFirstN("abcdef", 3) == 0);
 * assert("abc".compareFirstN("Abc", 3, true) == 0);
 * assert("abc".compareFirstN("abcdef", 6) < 0);
 * assert("abcdef".compareFirstN("abc", 6) > 0);
 * ---
 *
 * Params:
 *     s1 = the first string to be compared
 *     s2 = the second string to be compared
 *     length = the length of strings to be used in the comparison.
 *     caseInsensitive = if true, a case-insensitive comparison will be made,
 *                       otherwise a case-sensitive comparison will be made
 *
 * Returns: (for $(D pred = "a < b")):
 *
 * $(BOOKTABLE,
 * $(TR $(TD $(D < 0))  $(TD $(D s1 < s2) ))
 * $(TR $(TD $(D = 0))  $(TD $(D s1 == s2)))
 * $(TR $(TD $(D > 0))  $(TD $(D s1 > s2)))
 * )
 */
int compareFirstN (alias pred = "a < b", S1, S2) (S1 s1, S2 s2, size_t length, bool caseInsensitive = false)
    if (is(Unqual!(ElementType!(S1)) == dchar) && is(Unqual!(ElementType!(S2)) == dchar))
{
    auto s1End = length <= s1.length ? length : s1.length;
    auto s2End = length <= s2.length ? length : s2.length;

    auto slice1 = s1[0 .. s1End];
    auto slice2 = s2[0 .. s2End];

    return caseInsensitive ? slice1.icmp(slice2) : slice1.cmp(slice2);
}

unittest
{
    assert("abc".compareFirstN("abcdef", 3) == 0);
    assert("abc".compareFirstN("Abc", 3, true) == 0);
    assert("abc".compareFirstN("abcdef", 6) < 0);
    assert("abcdef".compareFirstN("abc", 6) > 0);
}

/*
 * Returns a range consisting of the elements of the $(D_PARAM input) range that
 * matches the given $(D_PARAM pattern).
 *
 * Examples:
 * ---
 * assert(equal(["ab", "0a", "cd", "1b"].grep(regex(`\d\w`)), ["0a", "1b"]));
 * assert(equal(["abc", "0123", "defg", "4567"].grep(regex(`(\w+)`), true), ["0123", "4567"]));
 * ---
 *
 * Params:
 *     input = the input range
 *     pattern = the regular expression pattern to search for
 *     invert = if $(D_KEYWORD true), this function returns the elements of the
 *              input range that do $(B not) match the given $(D_PARAM pattern).
 *
 * Returns: a range containing the matched elements
 */
auto grep (Range, Regex) (Range input, Regex pattern, bool invert = false)
{
    auto dg = invert ? (ElementType!(Range) e) { return e.match(pattern).empty; } :
                       (ElementType!(Range) e) { return !e.match(pattern).empty; };

    return filter!(dg)(input);
}

unittest
{
    assert(equal(["ab", "0a", "cd", "1b"].grep(regex(`\d\w`)), ["0a", "1b"]));
    assert(equal(["abc", "0123", "defg", "4567"].grep(regex(`4567`), true), ["abc", "0123", "defg"]));
}

/*
 * Pops the last element of the given range and returns the element.
 *
 * Examples:
 * ---
 * auto array = [0, 1, 2, 3];
 * auto    result = array.pop;
 *
 * assert(array == [0, 1, 2]);
 * assert(result == 3);
 * ---
 *
 * Params:
 *     range = the range to pop the element from
 *
 * Returns: the popped element
 */
ElementType!(A) pop (A) (ref A a) if (isDynamicArray!(A) && !isNarrowString!(A) && isMutable!(A) && !is(A == void[]))
{
    auto e = a.back;
    a.popBack;
    return e;
}

unittest
{
    auto array = [0, 1, 2, 3];
    auto result = array.pop;

    assert(array == [0, 1, 2]);
    assert(result == 3);
}

/*
 * Returns the character at the given index as a string. The returned string will be a
 * slice of the original string.
 *
 * Examples:
 * ---
 * assert("abc".get(1, 'b') == "b");
 * assert("löv".get(1, 'ö') == "ö");
 * ---
 *
 * Params:
 *     str = the string to get the character from
 *     index = the index of the character to get
 *     c = the character to return, or any other of the same length
 *
 * Returns: the character at the given index as a string
 */
const(T)[] get (T) (const(T)[] str, size_t index, dchar c)
{
    return str[index .. index + codeLength!(T)(c)];
}

unittest
{
    assert("abc".get(1, 'b') == "b");
    assert("löv".get(1, 'ö') == "ö");
}

// issue 4673
bool isNumeric (dchar c)
{
    switch (c)
    {
        case 'i':
        case '.':
        case '-':
        case '+':
        case 'u':
        case 'l':
        case 'L':
        case 'U':
        case 'I':
            return false;

        default:
    }

    return std.string.isNumeric(c);
}

// Issue 5744
import core.stdc.string : memcmp;

sizediff_t lastIndexOf(Char1, Char2)(in Char1[] s, const(Char2)[] sub,
        CaseSensitive cs = CaseSensitive.yes) if (isSomeChar!Char1 && isSomeChar!Char2)
{
    if (cs == CaseSensitive.yes)
    {
        Char2 c;

        if (sub.length == 0)
            return s.length;
        c = sub[0];
        if (sub.length == 1)
            return std.string.lastIndexOf(s, c);
        for (ptrdiff_t i = s.length - sub.length; i >= 0; i--)
        {
            if (s[i] == c)
            {
                if (memcmp(&s[i + 1], &sub[1], sub.length - 1) == 0)
                    return i;
            }
        }
        return -1;
    }
    else
    {
        dchar c;

        if (sub.length == 0)
            return s.length;
        c = sub[0];
        if (sub.length == 1)
            return std.string.lastIndexOf(s, c, cs);
        if (c <= 0x7F)
        {
            c = std.ascii.toLower(c);
            for (ptrdiff_t i = s.length - sub.length; i >= 0; i--)
            {
                if (std.ascii.toLower(s[i]) == c)
                {
                    if (icmp(s[i + 1 .. i + sub.length], sub[1 .. sub.length]) == 0)
                        return i;
                }
            }
        }
        else
        {
            for (ptrdiff_t i = s.length - sub.length; i >= 0; i--)
            {
                if (icmp(s[i .. i + sub.length], sub) == 0)
                    return i;
            }
        }
        return -1;
    }
}
