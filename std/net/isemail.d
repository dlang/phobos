/**
 * To validate an email address according to RFCs 5321, 5322 and others
 *
 * Copyright © 2008-2011, Dominic Sayers$(BR)
 * Test schema documentation Copyright © 2011, Daniel Marschall$(BR)
 * All rights reserved.
 *
 * Authors: Dominic Sayers <dominic@sayers.cc>, Jacob Carlborg
 * Copyright: Copyright © 2008-2011 Dominic Sayers. All rights reserved.
 * Test schema documentation: Copyright © 2011, Daniel Marschall
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Link: $(LINK http://www.dominicsayers.com/isemail)
 * Version: 3.0.13 - Version 3.0
 * 
 * Port to the D programming language:
 *     Jacob Carlborg
 * 
 * Standards: 
 * 		$(UL
 * 			$(LI RFC 5321),
 * 			$(LI RFC 5322)
 * 		 )
 *
 * References:
 * 		$(UL
 * 			$(LI $(LINK http://tools.ietf.org/html/rfc5321)),
 * 			$(LI $(LINK http://tools.ietf.org/html/rfc5322)),
 * 		 )
 * 
 * Source: $(PHOBOSSRC std/net/_isemail.d)
 */
module std.net.isemail;

import std.algorithm : ElementType, equal, uniq, filter, contains = canFind;
import std.array;
import std.regex;
import std.stdio;
import std.string;
import std.traits;
import std.conv;
import std.utf;

/**
 * Check that an email address conforms to RFCs 5321, 5322 and others
 *
 * As of Version 3.0, we are now distinguishing clearly between a Mailbox as defined
 * by RFC 5321 and an addr-spec as defined by RFC 5322. Depending on the context,
 * either can be regarded as a valid email address. The RFC 5321 Mailbox specification
 * is more restrictive (comments, white space and obsolete forms are not allowed)
 *
 * Params: 
 *     email = The email address to check
 *     checkDNS = If true then a DNS check for MX records will be made
 *     errorLevel = Determines the boundary between valid and invalid addresses.
 * 					Status codes above this number will be returned as-is,
 * 					status codes below will be returned as ISEMAIL_VALID. Thus the
 * 					calling program can simply look for ISEMAIL_VALID if it is
 * 					only interested in whether an address is valid or not. The
 * 					errorlevel will determine how "picky" is_email() is about
 * 					the address.
 *
 * 					If omitted or passed as false then isEmail() will return
 * 					true or false rather than an integer error or warning.
 *
 * 					NB Note the difference between $(D_PARAM errorLevel) = false and
 * 					$(D_PARAM errorLevel) = 0
 */
EmailStatus isEmail (string email, bool checkDNS = false, EmailStatusCode errorLevel = EmailStatusCode.Off)
{
    int threshold;
    bool diagnose;
    
    if (errorLevel == EmailStatusCode.On || errorLevel == EmailStatusCode.Off)
    {
        threshold = EmailStatusCode.Valid;
        diagnose = errorLevel == EmailStatusCode.On;
    }
    
    else
    {
		diagnose = true;

        switch (errorLevel)
        {
            case EmailStatusCode.Warning: threshold = Threshold; break;
            case EmailStatusCode.Error: threshold = EmailStatusCode.Valid; break;
            default: threshold = errorLevel;
        }
    }
    
    auto returnStatus = [EmailStatusCode.Valid];
    auto context = EmailPart.ComponentLocalPart;
    auto contextStack = [context];
    auto contextPrior = context;
    auto token = "";
    auto tokenPrior = "";
    auto parseData = [EmailPart.ComponentLocalPart : "", EmailPart.ComponentDomain : ""];
    auto atomList = [EmailPart.ComponentLocalPart : [""], EmailPart.ComponentDomain : [""]];
    auto elementCount = 0;
    auto elementLength = 0;
    auto hyphenFlag = false;
    auto endOrDie = false;
	auto crlfCount = int.min; // int.min == not defined

    foreach (i, e ; email)
    {
        token = email.get(i, e);

        switch (context)
        {
            case EmailPart.ComponentLocalPart:
                switch (token)
                {
                    case Token.OpenParenthesis:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.Comment : EmailStatusCode.DeprecatedComment;
                            
                        else
                        {
                            returnStatus ~= EmailStatusCode.Comment;
                            endOrDie = true;
                        }
                        
                        contextStack ~= context;
                        context = EmailPart.ContextComment;
                    break;
                    
                    case Token.Dot:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.ErrorDotStart : EmailStatusCode.ErrorConsecutiveDots;
                            
                        else
                        {
                            if (endOrDie)
                                returnStatus ~= EmailStatusCode.DeprecatedLocalPart;
                        }
                        
                        endOrDie = false;
                        elementLength = 0;
                        elementCount++;
                        parseData[EmailPart.ComponentLocalPart] ~= token;

						if (elementCount >= atomList[EmailPart.ComponentLocalPart].length)
							atomList[EmailPart.ComponentLocalPart] ~= "";
							
						else
							atomList[EmailPart.ComponentLocalPart][elementCount] = "";
                    break;
                    
                    case Token.DoubleQuote:
                        if (elementLength == 0)
                        {
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.Rfc5321QuotedString : EmailStatusCode.DeprecatedLocalPart;
                            
                            parseData[EmailPart.ComponentLocalPart] ~= token;
                            atomList[EmailPart.ComponentLocalPart][elementCount] ~= token;
                            elementLength++;
                            endOrDie = true;
                            contextStack ~= context;
                            context = EmailPart.ContextQuotedString;
                        }
                        
                        else
                            returnStatus ~= EmailStatusCode.ErrorExpectingText;
                    break;
                    
                    case Token.Cr:
                    case Token.Space:
                    case Token.Tab:
                        if ((token == Token.Cr) && ((++i == email.length) || (email.get(i, e) != Token.Lf)))
                        {
                            returnStatus ~= EmailStatusCode.ErrorCrNoLf;
                            break;
                        }

                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.FoldingWhitespace : EmailStatusCode.DeprecatedFoldingWhitespace;
                            
                        else
                            endOrDie = true;
                            
                        contextStack ~= context;
                        context = EmailPart.ContextFoldingWhitespace;
                        tokenPrior = token;
                    break;
                    
                    case Token.At:
                        if (contextStack.length != 1)
                            throw new Exception("Unexpected item on context stack");
                            
                        if (parseData[EmailPart.ComponentLocalPart] == "")
                            returnStatus ~= EmailStatusCode.ErrorNoLocalPart;
                            
                        else if (elementLength == 0)
                            returnStatus ~= EmailStatusCode.ErrorDotEnd;
                            
                        else if (parseData[EmailPart.ComponentLocalPart].length > 64)
                            returnStatus ~= EmailStatusCode.Rfc5322LocalTooLong;
                            
                        else if (contextPrior == EmailPart.ContextComment || contextPrior == EmailPart.ContextFoldingWhitespace)
                            returnStatus ~= EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt;
                            
                        context = EmailPart.ComponentDomain;
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
                                case EmailPart.ContextComment:
                                case EmailPart.ContextFoldingWhitespace:
                                    returnStatus ~= EmailStatusCode.ErrorTextAfterCommentFoldingWhitespace;
                                break;
                                
                                case EmailPart.ContextQuotedString:
                                    returnStatus ~= EmailStatusCode.ErrorTextAfterQuotedString;
                                break;
                                
                                default:
                                    throw new Exception("More text found where none is allowed, but unrecognised prior context: " ~ to!(string)(contextPrior));
                            }
                        }
                        
                        else
                        {
                            contextPrior = context;
                            auto ord = token.firstChar;

                            if (ord < 33 || ord > 126 || ord == 10 || Token.Specials.contains(token))
                                returnStatus ~= EmailStatusCode.ErrorExpectingText;

                            parseData[EmailPart.ComponentLocalPart] ~= token;
                            atomList[EmailPart.ComponentLocalPart][elementCount] ~= token;
                            elementLength++;                                
                        }
                }
            break;
            
            case EmailPart.ComponentDomain:
                switch (token)
                {
                    case Token.OpenParenthesis:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt : EmailStatusCode.DeprecatedComment;
                        
                        else
                        {
                            returnStatus ~= EmailStatusCode.Comment;
                            endOrDie = true;
                        }
                    
                        contextStack ~= context;
                        context = EmailPart.ContextComment;
                    break;
                    
                    case Token.Dot:
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.ErrorDotStart : EmailStatusCode.ErrorConsecutiveDots;
                            
                        else if (hyphenFlag)
                            returnStatus ~= EmailStatusCode.ErrorDomainHyphenEnd;
                            
                        else
                        {
                            if (elementLength > 63)
                                returnStatus ~= EmailStatusCode.Rfc5322LabelTooLong;
                        }
                        
                        endOrDie = false;
                        elementLength = 0,
                        elementCount++;

                        //atomList[EmailPart.ComponentDomain][elementCount] = "";
						atomList[EmailPart.ComponentDomain] ~= "";
                        parseData[EmailPart.ComponentDomain] ~= token;
                    break;
                    
                    case Token.OpenBracket:
                        if (parseData[EmailPart.ComponentDomain] == "")
                        {
                            endOrDie = true;
                            elementLength++;
                            contextStack ~= context;
                            context = EmailPart.ComponentLiteral;
                            parseData[EmailPart.ComponentDomain] ~= token;
                            atomList[EmailPart.ComponentDomain][elementCount] ~= token;
                            parseData[EmailPart.ComponentLiteral] = "";
                        }
                        
                        else
                            returnStatus ~= EmailStatusCode.ErrorExpectingText;
                    break;
                    
                    case Token.Cr:
                    case Token.Space:
                    case Token.Tab:
                        if (token == Token.Cr && (++i == email.length || email.get(i, e) != Token.Lf))
                        {
                            returnStatus ~= EmailStatusCode.ErrorCrNoLf;
                            break;
                        }
                        
                        if (elementLength == 0)
                            returnStatus ~= elementCount == 0 ? EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt : EmailStatusCode.DeprecatedFoldingWhitespace;
                            
                        else
                        {
                            returnStatus ~= EmailStatusCode.FoldingWhitespace;
                            endOrDie = true;
                        }
                        
                        contextStack ~= context;
                        context = EmailPart.ContextFoldingWhitespace;
                        tokenPrior = token;
                    break;
                    
                    default:
                        if (endOrDie)
                        {
                            switch (contextPrior)
                            {
                                case EmailPart.ContextComment:
                                case EmailPart.ContextFoldingWhitespace:
                                    returnStatus ~= EmailStatusCode.ErrorTextAfterCommentFoldingWhitespace;
                                break;
                                
                                case EmailPart.ComponentLiteral:
                                    returnStatus ~= EmailStatusCode.ErrorTextAfterDomainLiteral;
                                break;
                                
                                default:
                                    throw new Exception("More text found where none is allowed, but unrecognised prior context: " ~ to!(string)(contextPrior));
                            }                            
                            
                        }
                        
                        auto ord = token.firstChar;
                        hyphenFlag = false;
                        
                        if (ord < 33 || ord > 126 || Token.Specials.contains(token))
                            returnStatus ~= EmailStatusCode.ErrorExpectingText;
                            
                        else if (token == Token.Hyphen)
                        {
                            if (elementLength == 0)
                                returnStatus ~= EmailStatusCode.ErrorDomainHyphenStart;
                                
                            hyphenFlag = true;
                        }
                        
                        else if (!((ord > 47 && ord < 58) || (ord > 64 && ord < 91) || (ord > 96 && ord < 123)))
                            returnStatus ~= EmailStatusCode.Rfc5322Domain;
                            
                        parseData[EmailPart.ComponentDomain] ~= token;
                        atomList[EmailPart.ComponentDomain][elementCount] ~= token;
                        elementLength++;
                }
            break;
            
            case EmailPart.ComponentLiteral:
                switch (token)
                {
                    case Token.CloseBracket:
                        if (returnStatus.max < EmailStatusCode.Deprecated)
                        {
                            auto maxGroups = 8;
                            auto index = -1;
                            auto addressLiteral = parseData[EmailPart.ComponentLiteral];
                            auto matchesIp = array(addressLiteral.match(regex(`\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$`)).captures);
                            
                            if (!matchesIp.empty)
                            {
                                index = addressLiteral.lastIndexOf(matchesIp.first);
                                
                                if (index != 0)
                                    addressLiteral = addressLiteral.substr(0, index) ~ "0:0";
                            }
                            
                            if (index == 0)
                                returnStatus ~= EmailStatusCode.Rfc5321AddressLiteral;
                                
                            else if (addressLiteral.compareFirstN(Token.IpV6Tag, 5, true))
                                returnStatus ~= EmailStatusCode.Rfc5322DomainLiteral;
                                
                            else
                            {
                                auto ipV6 = addressLiteral.substr(5);
                                matchesIp = ipV6.split(Token.Colon);
                                auto groupCount = matchesIp.length;
                                index = ipV6.indexOf(Token.DoubleColon);
                                
                                if (index == -1)
                                {
                                    if (groupCount != maxGroups)
                                        returnStatus ~= EmailStatusCode.Rfc5322IpV6GroupCount;
                                }
                                
                                else
                                {
                                    if (index != ipV6.lastIndexOf(Token.DoubleColon))
                                        returnStatus ~= EmailStatusCode.Rfc5322IpV6TooManyDoubleColons;
                                        
                                    else
                                    {
                                        if (index == 0 || index == (ipV6.length - 2))
                                            maxGroups++;
                                            
                                        if (groupCount > maxGroups)
                                            returnStatus ~= EmailStatusCode.Rfc5322IpV6MaxGroups;
                                            
                                        else if (groupCount == maxGroups)
                                            returnStatus ~= EmailStatusCode.Rfc5321IpV6Deprecated;
                                    }
                                }
                                
                                if (ipV6.substr(0, 1) == Token.Colon && ipV6.substr(1, 1) != Token.Colon)
                                    returnStatus ~= EmailStatusCode.Rfc5322IpV6ColonStart;
                                    
                                else if (ipV6.substr(-1) == Token.Colon && ipV6.substr(-2, -1) != Token.Colon)
                                    returnStatus ~= EmailStatusCode.Rfc5322IpV6ColonEnd;
                                    
                                else if (!matchesIp.grep(regex(`^[0-9A-Fa-f]{0,4}$`), true).empty)
                                    returnStatus ~= EmailStatusCode.Rfc5322IpV6BadChar;
                                    
                                else
                                    returnStatus ~= EmailStatusCode.Rfc5321AddressLiteral;
                            }
                        }
                        
                        else
                            returnStatus ~= EmailStatusCode.Rfc5322DomainLiteral;
                            
                        parseData[EmailPart.ComponentDomain] ~= token;
                        atomList[EmailPart.ComponentDomain][elementCount] ~= token;
                        elementLength++;
                        contextPrior = context;
                        context = contextStack.pop;
                    break;
                    
                    case Token.Backslash:
                        returnStatus ~= EmailStatusCode.Rfc5322DomainLiteralObsoleteText;
                        contextStack ~= context;
                        context = EmailPart.ContextQuotedPair;
                    break;
                    
                    case Token.Cr:
                    case Token.Space:
                    case Token.Tab:
                        if (token == Token.Cr && (++i == email.length || email.get(i, e) != Token.Lf))
                        {
                            returnStatus ~= EmailStatusCode.ErrorCrNoLf;
                            break;
                        }
                        
                        returnStatus ~= EmailStatusCode.FoldingWhitespace;
                        contextStack ~= context;
                        context = EmailPart.ContextFoldingWhitespace;
                        tokenPrior = token;
                    break;
                    
                    default:
                        auto ord = token.firstChar;
                        
                        if (ord > 127 || ord == 0 || token == Token.OpenBracket)
                        {
                            returnStatus ~= EmailStatusCode.ErrorExpectingDomainText;
                            break;
                        }
                        
                        else if (ord < 33 || ord == 127)
                            returnStatus ~= EmailStatusCode.Rfc5322DomainLiteralObsoleteText;
                            
                        parseData[EmailPart.ComponentLiteral] ~= token;
                        parseData[EmailPart.ComponentDomain] ~= token;
                        atomList[EmailPart.ComponentDomain][elementCount] ~= token;
                        elementLength++;
                }
            break;
            
            case EmailPart.ContextQuotedString:
                switch (token)
                {
                    case Token.Backslash:
                        contextStack ~= context;
                        context = EmailPart.ContextQuotedPair;
                    break;
                    
                    case Token.Cr:
                    case Token.Tab:
                        if (token == Token.Cr && (++i == email.length || email.get(i, e) != Token.Lf))
                        {
                            returnStatus ~= EmailStatusCode.ErrorCrNoLf;
                            break;
                        }
                        
                        parseData[EmailPart.ComponentLocalPart] ~= Token.Space;
                        atomList[EmailPart.ComponentLocalPart][elementCount] ~= Token.Space;
                        elementLength++;
                        
                        returnStatus ~= EmailStatusCode.FoldingWhitespace;
                        contextStack ~= context;
                        context = EmailPart.ContextFoldingWhitespace;
                        tokenPrior = token;
                    break;
                    
                    case Token.DoubleQuote:
						parseData[EmailPart.ComponentLocalPart] ~= token;
						atomList[EmailPart.ComponentLocalPart][elementCount] ~= token;
						elementLength++;
						contextPrior = context;
						context = contextStack.pop;
					break;
					
					default:
						auto ord = token.firstChar;
						
						if (ord > 127 || ord == 0 || ord == 10)
							returnStatus ~= EmailStatusCode.ErrorExpectingQuotedText;
							
						else if (ord < 32 || ord == 127)
							returnStatus ~= EmailStatusCode.DeprecatedQuotedText;
							
						parseData[EmailPart.ComponentLocalPart] ~= token;
						atomList[EmailPart.ComponentLocalPart][elementCount] ~= token;
						elementLength++;
                }				
            break;

			case EmailPart.ContextQuotedPair:
				auto ord = token.firstChar;
				
				if (ord > 127)
					returnStatus ~= EmailStatusCode.ErrorExpectingQuotedPair;
					
				else if (ord < 31 && ord != 9 || ord == 127)
					returnStatus ~= EmailStatusCode.DeprecatedQuotedPair;
					
				contextPrior = context;
				context = contextStack.pop;
				token = Token.Backslash ~ token;

				switch (context)
				{
					case EmailPart.ContextComment: break;
					
					case EmailPart.ContextQuotedString:
						parseData[EmailPart.ComponentLocalPart] ~= token;
						atomList[EmailPart.ComponentLocalPart][elementCount] ~= token;
						elementLength += 2;
					break;
					
					case EmailPart.ComponentLiteral:
						parseData[EmailPart.ComponentDomain] ~= token;
						atomList[EmailPart.ComponentDomain][elementCount] ~= token;
						elementLength += 2;
					break;
					
					default:
						throw new Exception("Quoted pair logic invoked in an invalid context: " ~ to!(string)(context));
				}
			break;
			
			case EmailPart.ContextComment:
				switch (token)
				{
					case Token.OpenParenthesis:
						contextStack ~= context;
						context = EmailPart.ContextComment;
					break;
					
					case Token.CloseParenthesis:
						contextPrior = context;
						context = contextStack.pop;
					break;
					
					case Token.Backslash:
						contextStack ~= context;
						context = EmailPart.ContextQuotedPair;
					break;
					
					case Token.Cr:
					case Token.Space:
					case Token.Tab:
						if (token == Token.Cr && (i++ == email.length || email.get(i, e) != Token.Lf))
						{
							returnStatus ~= EmailStatusCode.ErrorCrNoLf;
							break;
						}
						
						returnStatus ~= EmailStatusCode.FoldingWhitespace;
						
						contextStack ~= context;
						context = EmailPart.ContextFoldingWhitespace;
						tokenPrior = token;
					break;
					
					default:
						auto ord = token.firstChar;
						
						if (ord > 127 || ord == 0 || ord == 10)
						{
							returnStatus ~= EmailStatusCode.ErrorExpectingCommentText;
							break;
						}
						
						else if (ord < 32 || ord == 127)
							returnStatus ~= EmailStatusCode.DeprecatedCommentText;
				}
			break;
			
			case EmailPart.ContextFoldingWhitespace:
				if (tokenPrior == Token.Cr)
				{
					if (token == Token.Cr)
					{
						returnStatus ~= EmailStatusCode.ErrorFoldingWhitespaceCrflX2;
						break;
					}

					if (crlfCount != int.min) // int.min == not defined
					{
						if (++crlfCount > 1)
							returnStatus ~= EmailStatusCode.DeprecatedFoldingWhitespace;
					}
					
					else
						crlfCount = 1;
				}
				
				switch (token)
				{
					case Token.Cr:
						if (++i == email.length || email.get(i, e) != Token.Lf)
							returnStatus ~= EmailStatusCode.ErrorCrNoLf;
					break;
					
					case Token.Space:
					case Token.Tab:						
					break;
					
					default:
						if (tokenPrior == Token.Cr)
						{
							returnStatus ~= EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd;
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

		if (returnStatus.max > EmailStatusCode.Rfc5322)
			break;
    }

	if (returnStatus.max < EmailStatusCode.Rfc5322)
	{
		if (context == EmailPart.ContextQuotedString)
			returnStatus ~= EmailStatusCode.ErrorUnclosedQuotedString;
			
		else if (context == EmailPart.ContextQuotedPair)
			returnStatus ~= EmailStatusCode.ErrorBackslashEnd;
			
		else if (context == EmailPart.ContextComment)
			returnStatus ~= EmailStatusCode.ErrorUnclosedComment;
			
		else if (context == EmailPart.ComponentLiteral)
			returnStatus ~= EmailStatusCode.ErrorUnclosedDomainLiteral;
			
		else if (token == Token.Cr)
			returnStatus ~= EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd;
			
		else if (parseData[EmailPart.ComponentDomain] == "")
			returnStatus ~= EmailStatusCode.ErrorNoDomain;
			
		else if (elementLength == 0)
			returnStatus ~= EmailStatusCode.ErrorDotEnd;
			
		else if (hyphenFlag)
			returnStatus ~= EmailStatusCode.ErrorDomainHyphenEnd;
			
		else if (parseData[EmailPart.ComponentDomain].length > 255)
			returnStatus ~= EmailStatusCode.Rfc5322DomainTooLong;
			
		else if ((parseData[EmailPart.ComponentLocalPart] ~ Token.At ~ parseData[EmailPart.ComponentDomain]).length > 254)
			returnStatus ~= EmailStatusCode.Rfc5322TooLong;
			
		else if (elementLength > 63)
			returnStatus ~= EmailStatusCode.Rfc5322LabelTooLong;
	}
	
	auto dnsChecked = false;
    
	if (checkDNS && returnStatus.max < EmailStatusCode.DnsWarning)
	{
		assert(false, "DNS check is currently not implemented");
	}
	
	if (!dnsChecked && returnStatus.max < EmailStatusCode.DnsWarning)
	{
		if (elementCount == 0)
			returnStatus ~= EmailStatusCode.Rfc5321TopLevelDomain;

		if (isNumeric(atomList[EmailPart.ComponentDomain][elementCount].first))
			returnStatus ~= EmailStatusCode.Rfc5321TopLevelDomainNumeric;			
	}
	
	returnStatus = array(std.algorithm.uniq(returnStatus));
	auto finalStatus = returnStatus.max;
	
	if (returnStatus.length != 1)
		returnStatus.shift;
		
	parseData[EmailPart.Status] = to!(string)(returnStatus);
	
	if (finalStatus < threshold)
		finalStatus = EmailStatusCode.Valid;

	if (!diagnose)
		finalStatus = finalStatus < Threshold ? EmailStatusCode.Valid : EmailStatusCode.Error;
		
	auto valid = finalStatus == EmailStatusCode.Valid;
	auto localPart = "";
	auto domainPart = "";
	
	if (auto value = EmailPart.ComponentLocalPart in parseData)
		localPart = *value;
		
	if (auto value = EmailPart.ComponentDomain in parseData)
		domainPart = *value;
		
	return EmailStatus(valid, localPart, domainPart, finalStatus);
}

unittest
{
	assert(``.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoDomain);
	assert(`test`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoDomain);
	assert(`@`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoLocalPart);
	assert(`test@`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoDomain);
	//assert(`test@io`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid, `io. currently has an MX-record (Feb 2011). Some DNS setups seem to find it, some don't. If you don't see the MX for io. then try setting your DNS server to 8.8.8.8 (the Google DNS server)`);
	assert(`@io`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoLocalPart, `io. currently has an MX-record (Feb 2011)`);
	assert(`@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoLocalPart);
	assert(`test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`test@nominet.org.uk`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`test@about.museum`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`a@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	//assert(`test@e.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord); // DNS check is currently not implemented
	//assert(`test@iana.a`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord); // DNS check is currently not implemented
	assert(`test.test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`.test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDotStart);
	assert(`test.@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDotEnd);
	assert(`test..iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorConsecutiveDots);
	assert(`test_exa-mple.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorNoDomain);
	assert("!#$%&`*+/=?^`{|}~@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`test\@test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`123@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`test@123.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`test@iana.123`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321TopLevelDomainNumeric);
	assert(`test@255.255.255.255`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321TopLevelDomainNumeric);
	assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklmn@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322LocalTooLong);
	//assert(`test@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord); // DNS check is currently not implemented 
	assert(`test@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322LabelTooLong);
	assert(`test@mason-dixon.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	assert(`test@-iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDomainHyphenStart);
	assert(`test@iana-.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDomainHyphenEnd);
	assert(`test@g--a.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid);
	//assert(`test@iana.co-uk`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord); // DNS check is currently not implemented 
	assert(`test@.iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDotStart);
	assert(`test@iana.org.`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDotEnd);
	assert(`test@iana..com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorConsecutiveDots);
	//assert(`a@a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord); // DNS check is currently not implemented 
	//assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghi`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord); // DNS check is currently not implemented 
	assert(`abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghij`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322TooLong);
	assert(`a@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefg.hij`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322TooLong);
	assert(`a@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefg.hijk`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainTooLong);
	assert(`"test"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321QuotedString);
	assert(`""@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321QuotedString);
	assert(`"""@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`"\a"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321QuotedString);
	assert(`"\""@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321QuotedString);
	assert(`"\"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedQuotedString);
	assert(`"\\"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321QuotedString);
	assert(`test"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`"test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedQuotedString);
	assert(`"test"test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorTextAfterQuotedString);
	assert(`test"text"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`"test""test"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`"test"."test"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedLocalPart);
	assert(`"test\ test"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321QuotedString);
	assert(`"test".test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedLocalPart);
	assert("\"test\u0000\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingQuotedText);
	assert("\"test\\\u0000\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedQuotedPair);
	assert(`"abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz abcdefghj"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322LocalTooLong, `Quotes are still part of the length restriction`);
	assert(`"abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz abcdefg\h"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322LocalTooLong, `Quoted pair is still part of the length restriction`);
	//assert(`test@[255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	assert(`test@a[255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	// assert(`test@[255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[255.255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[255.255.255.256]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[1111:2222:3333:4444:5555:6666:7777:8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6GroupCount); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:8888:9999]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6GroupCount); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:888G]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6BadChar); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666::8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321IpV6Deprecated); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555::8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666::7777:8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6MaxGroups); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6::3333:4444:5555:6666:7777:8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6ColonStart); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:::3333:4444:5555:6666:7777:8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111::4444:5555::8888]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6TooManyDoubleColons); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:::]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6GroupCount); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666:7777:255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6GroupCount); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444::255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321AddressLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:5555:6666::255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6MaxGroups); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6:1111:2222:3333:4444:::255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6TooManyDoubleColons); // std.regex bug: *+? not allowed in atom
	// assert(`test@[IPv6::255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6ColonStart); // std.regex bug: *+? not allowed in atom
	assert(` test @iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt);
	assert(`test@ iana .com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt);
	assert(`test . test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedFoldingWhitespace);
	assert("\u000D\u000A test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.FoldingWhitespace, `Folding whitespace`);
	assert("\u000D\u000A \u000D\u000A test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedFoldingWhitespace, `FWS with one line composed entirely of WSP -- only allowed as obsolete FWS (someone might allow only non-obsolete FWS)`);
	assert(`(comment)test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Comment);
	assert(`((comment)test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedComment);
	assert(`(comment(comment))test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Comment);
	assert(`test@(comment)iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt);
	assert(`test(comment)test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorTextAfterCommentFoldingWhitespace);
	// assert(`test@(comment)[255.255.255.255]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt); // std.regex bug: *+? not allowed in atom
	assert(`(comment)abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghiklm@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Comment);
	assert(`test@(comment)abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghikl.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentFoldingWhitespaceNearAt);
	assert(`(comment)test@abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghik.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghik.abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk.abcdefghijklmnopqrstuvwxyzabcdefghijk.abcdefghijklmnopqrstu`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Comment);
	assert("test@iana.org\u000A".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`test@xn--hxajbheg2az3al.xn--jxalpdlp`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid, `A valid IDN from ICANN's <a href="http://idn.icann.org/#The_example.test_names">IDN TLD evaluation gateway</a>`);
	assert(`xn--test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Valid, `RFC 3490: "unless the email standards are revised to invite the use of IDNA for local parts, a domain label that holds the local part of an email address SHOULD NOT begin with the ACE prefix, and even if it does, it is to be interpreted literally as a local part that happens to begin with the ACE prefix"`);
	assert(`test@iana.org-`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorDomainHyphenEnd);
	assert(`"test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedQuotedString);
	assert(`(test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedComment);
	assert(`test@(iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedComment);
	assert(`test@[1.2.3.4`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedDomainLiteral);
	assert(`"test\"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedQuotedString);
	assert(`(comment\)test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedComment);
	assert(`test@iana.org(comment\)`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedComment);
	assert(`test@iana.org(comment\`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorBackslashEnd);
	// assert(`test@[RFC-5322-domain-literal]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC-5322]-domain-literal]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorTextAfterDomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC-5322-[domain-literal]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingDomainText); // std.regex bug: *+? not allowed in atom
	// assert("test@[RFC-5322-\\\u0007-domain-literal]".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteralObsoleteText, `obs-dtext <strong>and</strong> obs-qp`); // std.regex bug: *+? not allowed in atom
	// assert("test@[RFC-5322-\\\u0009-domain-literal]".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteralObsoleteText); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC-5322-\]-domain-literal]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteralObsoleteText); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC-5322-domain-literal\]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorUnclosedDomainLiteral); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC-5322-domain-literal\`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorBackslashEnd); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC 5322 domain literal]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral, `Spaces are FWS in a domain literal`); // std.regex bug: *+? not allowed in atom
	// assert(`test@[RFC-5322-domain-literal] (comment)`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322DomainLiteral); // std.regex bug: *+? not allowed in atom
	assert(`@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`test@.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert(`""@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedQuotedText);
	assert(`"\"@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedQuotedPair);
	assert(`()test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentText);
	assert("test@iana.org\u000D".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorCrNoLf, `No LF after the CR`);
	assert("\u000Dtest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorCrNoLf, `No LF after the CR`);
	assert("\"\u000Dtest\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorCrNoLf, `No LF after the CR`);
	assert("(\u000D)test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorCrNoLf, `No LF after the CR`);
	assert("test@iana.org(\u000D)".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorCrNoLf, `No LF after the CR`);
	assert("\u000Atest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert("\"\u000A\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingQuotedText);
	assert("\"\\\u000A\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedQuotedPair);
	assert("(\u000A)test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingCommentText);
	assert("\u0007@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert("test@\u0007.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingText);
	assert("\"\u0007\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedQuotedText);
	assert("\"\\\u0007\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedQuotedPair);
	assert("(\u0007)test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedCommentText);
	assert("\u000D\u000Atest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not FWS because no actual white space`);
	assert("\u000D\u000A \u000D\u000Atest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not obs-FWS because there must be white space on each "fold"`);
	assert(" \u000D\u000Atest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the fold`);
	assert(" \u000D\u000A test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.FoldingWhitespace, `FWS`);
	assert(" \u000D\u000A \u000D\u000Atest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the second fold`);
	assert(" \u000D\u000A\u000D\u000Atest@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrflX2, `Not FWS because no white space after either fold`);
	assert(" \u000D\u000A\u000D\u000A test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrflX2, `Not FWS because no white space after the first fold`);
	assert("test@iana.org\u000D\u000A ".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.FoldingWhitespace, `FWS`);
	assert("test@iana.org\u000D\u000A \u000D\u000A ".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedFoldingWhitespace, `FWS with one line composed entirely of WSP -- only allowed as obsolete FWS (someone might allow only non-obsolete FWS)`);
	assert("test@iana.org\u000D\u000A".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not FWS because no actual white space`);
	assert("test@iana.org\u000D\u000A \u000D\u000A".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not obs-FWS because there must be white space on each "fold"`);
	assert("test@iana.org \u000D\u000A".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the fold`);
	assert("test@iana.org \u000D\u000A ".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.FoldingWhitespace, `FWS`);
	assert("test@iana.org \u000D\u000A \u000D\u000A".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrLfEnd, `Not FWS because no white space after the second fold`);
	assert("test@iana.org \u000D\u000A\u000D\u000A".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrflX2, `Not FWS because no white space after either fold`);
	assert("test@iana.org \u000D\u000A\u000D\u000A ".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorFoldingWhitespaceCrflX2, `Not FWS because no white space after the first fold`);
	assert(" test@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.FoldingWhitespace);
	assert(`test@iana.org `.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.FoldingWhitespace);
	// assert(`test@[IPv6:1::2:]`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322IpV6ColonEnd); // std.regex bug: *+? not allowed in atom
	assert("\"test\\\u00A9\"@iana.org".isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.ErrorExpectingQuotedPair);
	assert(`test@iana/icann.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5322Domain);
	assert(`test.(comment)test@iana.org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DeprecatedComment);
	assert(`test@org`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.Rfc5321TopLevelDomain);
	// assert(`test@test.com`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoMXRecord, `test.com has an A-record but not an MX-record`); // DNS check is currently not implemented
	// assert(`test@nic.no`.isEmail(false, EmailStatusCode.On).statusCode == EmailStatusCode.DnsWarningNoRecord, `nic.no currently has no MX-records or A-records (Feb 2011). If you are seeing an A-record for nic.io then try setting your DNS server to 8.8.8.8 (the Google DNS server) - your DNS server may be faking an A-record (OpenDNS does this, for instance).`); // DNS check is currently not implemented
}

/// This struct represents the status of an email address
struct EmailStatus
{
	/// Indicates if the email address is valid or not.
	const bool valid;
	
	/// The local part of the email address, that is, the part before the @ sign.
	const string localPart;
	
	/// The domain part of the email address, that is, the part after the @ sign.
	const string domainPart;
	
	/// The email status code
	const EmailStatusCode statusCode;
	
	alias valid this;
	
	/**
	 * Params:
	 *     valid = indicates if the email address is valid or not
	 *     localPart = the local part of the email address
	 *     domainPart = the domain part of the email address
	 * 	   statusCode = the status code
	 */  
	this (bool valid, string localPart, string domainPart, EmailStatusCode statusCode)
	{
		this.valid = valid;
		this.localPart = localPart;
		this.domainPart = domainPart;
		this.statusCode = statusCode;
	}
	
	/// Returns the email status as a string
	string status ()
	{
		return "";
	}
	
	/// Returns a textual representation of the email status
	string toString ()
	{
		return format("EmailStatus\n{\n\tvalid: %s\n\tlocalPart: %s\n\tdomainPart: %s\n\tstatusCode: %s\n}", valid, localPart, domainPart, statusCode);
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
    ValidCategory = 1,

	/// Address is valid but a DNS check was not successful
    DnsWarning = 7,

	/// Address is valid for SMTP but has unusual elements
    Rfc5321 = 15,

	/// Address is valid within the message but cannot be used unmodified for the envelope
    CFoldingWhitespace = 31,

	/// Address contains deprecated elements but may still be valid in restricted contexts
    Deprecated = 63,

	/// The address is only valid according to the broad definition of RFC 5322. It is otherwise invalid
    Rfc5322 = 127,

	///
	On = 252,
	
	///
	Off = 253,
	
	///
	Warning = 254,
	
	/// Address is invalid for any purpose
    Error = 255,
    


    // Diagnoses

    /// Address is valid
    Valid = 0,
    
	// Address is valid but a DNS check was not successful

    /// Could not find an MX record for this domain but an A-record does exist
    DnsWarningNoMXRecord = 5,

	/// Could not find an MX record or an A-record for this domain
    DnsWarningNoRecord = 6,
    


	// Address is valid for SMTP but has unusual elements

    /// Address is valid but at a Top Level Domain
    Rfc5321TopLevelDomain = 9,

	/// Address is valid but the Top Level Domain begins with a number
    Rfc5321TopLevelDomainNumeric = 10,

	/// Address is valid but contains a quoted string
    Rfc5321QuotedString = 11,

	/// Address is valid but at a literal address not a domain
    Rfc5321AddressLiteral = 12,

	/// Address is valid but contains a :: that only elides one zero group
    Rfc5321IpV6Deprecated = 13,
    


	// Address is valid within the message but cannot be used unmodified for the envelope

    /// Address contains comments
    Comment = 17,

	/// Address contains Folding White Space
    FoldingWhitespace = 18,
    


	// Address contains deprecated elements but may still be valid in restricted contexts

    /// The local part is in a deprecated form
    DeprecatedLocalPart = 33,

	/// Address contains an obsolete form of Folding White Space
    DeprecatedFoldingWhitespace = 34,

	/// A quoted string contains a deprecated character
    DeprecatedQuotedText = 35,

	/// A quoted pair contains a deprecated character
	DeprecatedQuotedPair = 36,
	
	/// Address contains a comment in a position that is deprecated
    DeprecatedComment = 37,

	/// A comment contains a deprecated character
    DeprecatedCommentText = 38,

	/// Address contains a comment or Folding White Space around the @ sign
    DeprecatedCommentFoldingWhitespaceNearAt = 49,
    


	// The address is only valid according to the broad definition of RFC 5322

    /// Address is RFC 5322 compliant but contains domain characters that are not allowed by DNS
    Rfc5322Domain = 65,

	/// Address is too long
    Rfc5322TooLong = 66,

	/// The local part of the address is too long
    Rfc5322LocalTooLong = 67,

	/// The domain part is too long
    Rfc5322DomainTooLong = 68,

	/// The domain part contains an element that is too long
    Rfc5322LabelTooLong = 69,

	/// The domain literal is not a valid RFC 5321 address literal
    Rfc5322DomainLiteral = 70,

	/// The domain literal is not a valid RFC 5321 address literal and it contains obsolete characters
    Rfc5322DomainLiteralObsoleteText = 71,

	/// The IPv6 literal address contains the wrong number of groups
    Rfc5322IpV6GroupCount = 72,

	/// The IPv6 literal address contains too many :: sequences
    Rfc5322IpV6TooManyDoubleColons = 73,

	/// The IPv6 address contains an illegal group of characters
    Rfc5322IpV6BadChar = 74,

	/// The IPv6 address has too many groups
    Rfc5322IpV6MaxGroups = 75,

	/// IPv6 address starts with a single colon
    Rfc5322IpV6ColonStart = 76,

	/// IPv6 address ends with a single colon
    Rfc5322IpV6ColonEnd = 77,
    


    // Address is invalid for any purpose
	
	/// A domain literal contains a character that is not allowed
    ErrorExpectingDomainText = 129,

	/// Address has no local part
    ErrorNoLocalPart = 130,

	/// Address has no domain part
    ErrorNoDomain = 131,

	/// The address may not contain consecutive dots
    ErrorConsecutiveDots = 132,

	/// Address contains text after a comment or Folding White Space
    ErrorTextAfterCommentFoldingWhitespace = 133,

	/// Address contains text after a quoted string
    ErrorTextAfterQuotedString = 134,

	/// Extra characters were found after the end of the domain literal
    ErrorTextAfterDomainLiteral = 135,

	/// The address contains a character that is not allowed in a quoted pair
    ErrorExpectingQuotedPair = 136,

	/// Address contains a character that is not allowed
    ErrorExpectingText = 137,

	/// A quoted string contains a character that is not allowed
    ErrorExpectingQuotedText = 138,

	/// A comment contains a character that is not allowed
    ErrorExpectingCommentText = 139,

	/// The address cannot end with a backslash
    ErrorBackslashEnd = 140,

	/// Neither part of the address may begin with a dot
    ErrorDotStart = 141,

	/// Neither part of the address may end with a dot
    ErrorDotEnd = 142,

	/// A domain or subdomain cannot begin with a hyphen
    ErrorDomainHyphenStart = 143,

	/// A domain or subdomain cannot end with a hyphen
    ErrorDomainHyphenEnd = 144,

	/// Unclosed quoted string
    ErrorUnclosedQuotedString = 145,

	/// Unclosed comment
    ErrorUnclosedComment = 146,

	/// Domain literal is missing its closing bracket
    ErrorUnclosedDomainLiteral = 147,

	/// Folding White Space contains consecutive CRLF sequences
    ErrorFoldingWhitespaceCrflX2 = 148,

	/// Folding White Space ends with a CRLF sequence
    ErrorFoldingWhitespaceCrLfEnd = 149,

	/// Address contains a carriage return that is not followed by a line feed
    ErrorCrNoLf = 150,
}

private:

alias front first;
alias back last;
alias popFront shift;
	
enum Threshold = 16;
	
/// Email parts for the isEmail function
enum EmailPart
{
	/// The local part of the email address, that is, the part before the @ sign
    ComponentLocalPart,

	/// The domain part of the email address, that is, the part after the @ sign.
	ComponentDomain,

    ComponentLiteral,
    ContextComment,
    ContextFoldingWhitespace,
    ContextQuotedString,
    ContextQuotedPair,
	Status
}

// Miscellaneous string constants
struct Token
{
	static:
	
	enum
	{
		At = "@",
        Backslash = `\`,
        Dot = ".",
        DoubleQuote = `"`,
        OpenParenthesis = "(",
        CloseParenthesis = ")",
        OpenBracket = "[",
        CloseBracket = "]",
        Hyphen = "-",
        Colon = ":",
        DoubleColon = "::",
        Space = " ",
        Tab = "\t",
        Cr = "\r",
        Lf = "\n",
        IpV6Tag = "IPV6:",

        // US-ASCII visible characters not valid for atext (http://tools.ietf.org/html/rfc5322#section-3.2.3)
        Specials = `()<>[]:;@\\,."`
	}
}

/**
 * Returns the integer value of the first character in the given string.
 * 
 * Examples:
 * ---
 * assert("abcde".firstChar == 97);
 * ---
 * 
 * Params:
 *     str = the string to get the first character from
 *
 * Returns: the first character as an integer
 */
int firstChar (Char) (in Char[] str) if (isSomeChar!(Char))
{
    return cast(int) str.first;
}

unittest
{
	assert("abcde".firstChar == 97);
	assert("över".firstChar == 246);
}

/**
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
    auto max = arr.first;
    
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

/**
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
 *			   $(D_PARAM start)'th position in $(D_PARAM str), counting from zero.
 *			   For instance, in the string "abcdef", the character at position 0 is 'a',
 * 			   the character at position 2 is 'c', and so forth.
 * 
 * 			   If $(D_PARAM start) is negative, the returned string will start at the
 * 			   $(D_PARAM start)'th character from the end of $(D_PARAM str).
 * 
 * 			   If $(D_PARAM str) is less than or equal to $(D_PARAM start) characters long,
 * 			   $(D_KEYWORD true) will be returned.
 * 
 *     length = if $(D_PARAM length) is given and is positive, the string returned will
 *				contain at most $(D_PARAM length) characters beginning from $(D_PARAM start)
 *				(depending on the length of string).
 *
 *				If $(D_PARAM length) is given and is negative, then that many characters
 *				will be omitted from the end of string (after the start position has been
 *				calculated when a $(D_PARAM start) is negative). If $(D_PARAM start)
 *				denotes the position of this truncation or beyond, $(D_KEYWORD false)
 *				will be returned.
 *
 *				If $(D_PARAM length) is given and is 0, an empty string will be returned.
 *
 *				If $(D_PARAM length) is omitted, the substring starting from $(D_PARAM start)
 *				until the end of the string will be returned.
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

/**
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
 * 						 otherwise a case-sensitive comparison will be made
 *      
 * Returns: (for $(D pred = "a < b")):
 * 
 * $(BOOKTABLE,
 * $(TR $(TD $(D < 0))  $(TD $(D s1 < s2) ))
 * $(TR $(TD $(D = 0))  $(TD $(D s1 == s2)))
 * $(TR $(TD $(D > 0))  $(TD $(D s1 > s2)))
 * )
 */
int compareFirstN (alias pred = "a < b", S1, S2) (S1 s1, S2 s2, size_t length, bool caseInsensitive = false) if (is(Unqual!(ElementType!(S1)) == dchar) && is(Unqual!(ElementType!(S2)) == dchar))
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

/**
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
 * 				input range that do $(B not) match the given $(D_PARAM pattern). 
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

/**
 * Pops the last element of the given range and returns the element.
 * 
 * Examples:
 * ---
 * auto array = [0, 1, 2, 3];
 * auto	result = array.pop;
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
	auto e = a.last;
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

/**
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
T[] get (T) (T[] str, size_t index, dchar c)
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


void main ()
{

}