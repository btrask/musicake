/* Copyright (c) 2009, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * The names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import <Foundation/Foundation.h>
#import <openssl/md5.h>

static NSString *const MCDefaultHost = @"eng.musicshake.com";
static NSString *const MCContestNumParameter = @"CONTEST_NUM";
static NSString *const MCSecret = @"@#!mshaker";

static NSString *const MCTicketURLElementName = @"TICKETURL";
static NSString *const MCSongItemElementName = @"item";
static NSString *const MCDescriptionElementName = @"desc";

static NSString *const MCSModeAttribute = @"smode";
static NSString *const MCSModeSingleSong = @"2";

static NSString *const MCSongItemNumberAttribute = @"SONG_NUM";
static NSString *const MCSongItemTitleAttribute = @"SONG_TITLE";
static NSString *const MCSongItemAlbumArtURLAttribute = @"CONTEST_IMAGE";

BOOL MCDownloadSong(NSXMLElement *item, NSURL *ticketURL, NSString *destinationPath);

@interface NSString(MCAdditions)
- (NSString *)MC_stringByStandardizingPathWithCurrentWorkingDirectory;
@end
@interface NSURL(MCAdditions)
- (NSDictionary *)MC_parameters;
@end
@interface NSXMLElement(MCAdditions)
- (NSXMLElement *)MC_elementForName:(NSString *)name;
- (NSString *)MC_valueForAttributeName:(NSString *)name;
- (NSArray *)MC_songItems;
@end
@interface NSData(MCAdditions)
- (NSData *)MC_MD5Hash;
- (NSString *)MC_hexString;
@end

enum {
	MCExecutablePathArgumentIndex,
	MCSourceArgumentIndex,
	MCDestinationPathArgumentIndex,
};
int main(int argc, const char *argv[]) {
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSArray *const arguments = [[NSProcessInfo processInfo] arguments];
	if(argc <= MCSourceArgumentIndex) {
		printf("musicake v1 Copyright (c) 2009, Ben Trask. BSD licensed.\n");
		printf("Usage 1: musicake URL [path]\n");
		printf("Usage 2: musicake CONTEST_NUM [path]\n");
		printf("Download and save a song from musicshake.\n");
		[pool drain];
		return EXIT_SUCCESS;
	}

	NSString *const srcString = [arguments objectAtIndex:MCSourceArgumentIndex];
	NSURL *const srcURL = [NSURL URLWithString:srcString];
	NSString *host = [srcURL host];
	if(!host) host = MCDefaultHost;
	NSString *ticket = [[srcURL MC_parameters] objectForKey:MCContestNumParameter];
	if(!ticket) ticket = srcString;

	NSURL *const XMLURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/XML/CONTEST/%@", host, ticket]];
	NSError *XMLError = nil;
	NSXMLDocument *const XMLDocument = [[[NSXMLDocument alloc] initWithContentsOfURL:XMLURL options:NSXMLNodeOptionsNone error:&XMLError] autorelease];
	if(!XMLDocument) {
		printf("Error: %s\n", [[XMLError localizedDescription] UTF8String]);
		[pool drain];
		return EXIT_FAILURE;
	}
	NSXMLElement *const mainNode = [XMLDocument rootElement];
	NSURL *const ticketURL = [NSURL URLWithString:[[mainNode MC_elementForName:MCTicketURLElementName] stringValue]];
	if(!ticketURL) {
		printf("Unable to determine ticket URL.\n");
		[pool drain];
		return EXIT_FAILURE;
	}
	NSArray *const songItems = [mainNode MC_songItems];

	NSString *const destinationPath = [argc > MCDestinationPathArgumentIndex ? [arguments objectAtIndex:MCDestinationPathArgumentIndex] : @"" MC_stringByStandardizingPathWithCurrentWorkingDirectory];

	NSUInteger successCount = 0;
	for(NSXMLElement *const item in songItems) if(MCDownloadSong(item, ticketURL, destinationPath)) successCount++;
	printf("Downloaded %lu out of %lu song(s).\n", (unsigned long)successCount, (unsigned long)[songItems count]);

	[pool drain];
	return EXIT_SUCCESS;
}

BOOL MCDownloadSong(NSXMLElement *item, NSURL *ticketURL, NSString *destinationPath) {
	NSString *const songTitle = [item MC_valueForAttributeName:MCSongItemTitleAttribute];

	NSURL *const ticketURLWithParameters = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?p=1", [ticketURL absoluteString], [item MC_valueForAttributeName:MCSongItemNumberAttribute]]];
	NSError *ticketError = nil;
	NSString *const ticketString = [NSString stringWithContentsOfURL:ticketURLWithParameters encoding:NSUTF8StringEncoding error:&ticketError];
	if(!ticketString) {
		printf("Error (%s): %s\n", [songTitle UTF8String], [[ticketError localizedDescription] UTF8String]);
		return NO;
	}
	NSScanner *const ticketScanner = [NSScanner scannerWithString:ticketString];
	NSString *songURLString = nil;
	if(![ticketScanner scanUpToString:@"||" intoString:&songURLString]) {
		printf("Error (%s): Unable to determine song URL.\n", [songTitle UTF8String]);
		return NO;
	}
	[ticketScanner scanString:@"||" intoString:NULL];
	NSString *ticketNum = nil;
	if(![ticketScanner scanUpToString:@"||" intoString:&ticketNum]) {
		printf("Error (%s): Unable to determine ticket number.\n", [songTitle UTF8String]);
		return NO;
	}

	NSString *const key = [[[[ticketNum stringByAppendingString:MCSecret] dataUsingEncoding:NSUTF8StringEncoding] MC_MD5Hash] MC_hexString];
	NSURL *const songURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?TICKET_NUM=%@&key=%@", songURLString, ticketNum, key]];
	NSData *const songData = [NSData dataWithContentsOfURL:songURL options:kNilOptions error:NULL];
	NSString *const songDestination = [destinationPath stringByAppendingPathComponent:[songTitle stringByAppendingString:@".mp3"]];
	if(![songData writeToFile:songDestination options:NSDataWritingAtomic error:NULL]) {
		printf("Error (%s): Unable to write song to path: %s\n", [songTitle UTF8String], [songDestination UTF8String]);
		return NO;
	}

	NSURL *const albumArtURL = [NSURL URLWithString:[item MC_valueForAttributeName:MCSongItemAlbumArtURLAttribute]];
	NSData *const albumArtData = [NSData dataWithContentsOfURL:albumArtURL options:kNilOptions error:NULL];
	NSString *const albumArtDestination = [destinationPath stringByAppendingPathComponent:[songTitle stringByAppendingFormat:@".%@", [[albumArtURL path] pathExtension]]];
	if(![albumArtData writeToFile:albumArtDestination options:NSDataWritingAtomic error:NULL]) printf("Error (%s): Unable to write album art to path: %s\n", [songTitle UTF8String], [albumArtDestination UTF8String]);

	printf("Downloaded successfully (%s)\n", [songTitle UTF8String]);
	return YES;
}

@implementation NSString(MCAdditions)
- (NSString *)MC_stringByStandardizingPathWithCurrentWorkingDirectory {
	if([self isAbsolutePath]) return [self stringByStandardizingPath];
	char *const cwd = getcwd(NULL, SIZE_MAX);
	NSString *const workingDirectory = [[[NSString alloc] initWithBytesNoCopy:cwd length:strlen(cwd) encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
	return [[workingDirectory stringByAppendingPathComponent:self] stringByStandardizingPath];
}
@end
@implementation NSURL(MCAdditions)
- (NSDictionary *)MC_parameters {
	NSMutableDictionary *const result = [NSMutableDictionary dictionary];
	NSScanner *const scanner = [NSScanner scannerWithString:[self absoluteString]];
	[scanner scanUpToString:@"?" intoString:NULL];
	if(![scanner scanString:@"?" intoString:NULL]) return nil;
	NSCharacterSet *const set = [NSCharacterSet characterSetWithCharactersInString:@"&#"];
	while(![scanner isAtEnd]) {
		NSString *key = nil, *value = nil;
		if(![scanner scanUpToString:@"=" intoString:&key] || ![scanner scanString:@"=" intoString:NULL]) break;
		if(![scanner scanUpToCharactersFromSet:set intoString:&value]) break;
		[scanner scanCharactersFromSet:set intoString:NULL];
		if(key && value) [result setObject:value forKey:key];
	}
	return result;
}
@end
@implementation NSXMLElement(MCAdditions)
- (NSXMLElement *)MC_elementForName:(NSString *)name {
	NSArray *const elements = [self elementsForName:name];
	return [elements count] ? [elements objectAtIndex:0] : nil;
}
- (NSString *)MC_valueForAttributeName:(NSString *)name {
	return [[self attributeForName:name] stringValue];
}
- (NSArray *)MC_songItems {
	NSMutableArray *const items = [[[self elementsForName:MCSongItemElementName] mutableCopy] autorelease];
	if([items count] && ![MCSModeSingleSong isEqualToString:[[self MC_elementForName:MCDescriptionElementName] MC_valueForAttributeName:MCSModeAttribute]]) [items removeObjectAtIndex:0];
	return items;
}
@end
@implementation NSData(MCAdditions)
- (NSData *)MC_MD5Hash {
	NSMutableData *const hashData = [NSMutableData dataWithLength:MD5_DIGEST_LENGTH];
	MD5([self bytes], [self length], [hashData mutableBytes]);
	return hashData;
}
- (NSString *)MC_hexString {
	// Based on <http://www.cocoadev.com/index.pl?NSDataCategory>.
	char const mapping[] = "0123456789abcdef";
	NSMutableString *const hex = [NSMutableString string];
	u_int8_t const *const bytes = [self bytes];
	NSUInteger const length = [self length];
	NSUInteger i = 0;
	for(; i < length; i++) [hex appendFormat:@"%c%c", mapping[bytes[i] >> 4], mapping[bytes[i] & 0x0f]];
	return hex;
}
@end
