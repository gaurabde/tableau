# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
# Patents Pending.
#
# common/ruby/lib/string_escaping.rb
# -----------------------------------------------------------------------

# NOTE-jrockwood-09-23-2010
# -------------------------
# Contains escaping methods that should be used instead of the built-in Rails
# html_escape (h) or json_escape (j). For the reasons, see the comments in front
# of each escaping method below.
#
# I can't stress enough how important it is to get your encodings correct. Failure
# to do so will result in an XSS (Cross-site security) attack vector. Since we're
# on the wild public web I can guarantee that eventually an attacker will find
# any places that we didn't encode properly. All it takes is one time and then
# you're owned (or pwned if you're so inclined - see http://en.wikipedia.org/wiki/Owned).

class Array
  def to_browser_json
    StringEscaping.to_browser_json(self)
  end
end

class String
  def to_html_content
    StringEscaping.to_html_content(self)
  end

  def to_html_attr(allow_double_escaping = false)
    StringEscaping.to_html_attr(self, allow_double_escaping)
  end

  def to_browser_json
    StringEscaping.to_browser_json(self)
  end

  def to_js_string(quote_char = nil)
    StringEscaping.to_js_string(self, quote_char)
  end
end

class Integer
  def to_html_content
    self.to_s
  end

  def to_html_attr
    StringEscaping.to_html_attr(self.to_s)
  end

  def to_browser_json
    self.to_json
  end

  def to_js_string(quote_char = nil)
    StringEscaping.to_js_string(self.to_s, quote_char)
  end
end

class TrueClass
  def to_html_content
    'true'
  end

  def to_html_attr
    'true'
  end

  def to_browser_json
    'true'
  end

  def to_js_string(quote_char = nil)
    StringEscaping.to_js_string('true', quote_char)
  end
end

class FalseClass
  def to_html_content
    'false'
  end

  def to_html_attr
    'false'
  end

  def to_browser_json
    'false'
  end

  def to_js_string(quote_char = nil)
    StringEscaping.to_js_string('false', quote_char)
  end
end

class NilClass
  def to_html_content
    ''
  end

  def to_html_attr
    ''
  end

  def to_browser_json
    'null'
  end

  def to_js_string(quote_char = nil)
    StringEscaping.to_js_string('null', quote_char)
  end
end

# The following methods implement the guidelines found in the XSS Cheat Sheet at
# http://www.owasp.org/index.php/XSS_(Cross_Site_Scripting)_Prevention_Cheat_Sheet
module StringEscaping

  # RULE #1 - HTML Escape Before Inserting Untrusted Data into HTML Element Content
  # -------------------------------------------------------------------------------
  # Rule #1 is for when you want to put untrusted data directly into the HTML
  # body somewhere. This includes inside normal tags like div, p, b, td, etc.
  # Most web frameworks have a method for HTML escaping for the characters
  # detailed below. However, this is absolutely not sufficient for other HTML
  # contexts. You need to implement the other rules detailed here as well.
  #
  # <body>...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...</body>
  # <div>...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...</div>
  # any other normal HTML elements
  #
  # Escape the following characters with HTML entity encoding to prevent switching
  # into any execution context, such as script, style, or event handlers. Using
  # hex entities is recommended in the spec. In addition to the 5 characters
  # significant in XML (&, <, >, ", '), the forward slash is included as it
  # helps to end an HTML entity.
  #
  # & --> &amp;
  # < --> &lt;
  # > --> &gt;
  # " --> &quot;
  # ' --> &#x27;     &apos; is not recommended
  # / --> &#x2F;     forward slash is included as it helps end an HTML entity
  def self.to_html_content(str)
    escaped = str.gsub(/\&|\<|\>|\"|\'|\//) do |match|
      # get the one and only character match
      cval = match[0]

      # look up the HTML entity so we can use that first instead of the hex code
      entity = HTML_ENTITIES[cval]
      if (!entity.nil?)
        '&' + entity + ';'
      else
        self.to_html_hex_entity(cval)
      end
    end
  end

  # RULE #2 - Attribute Escape Before Inserting Untrusted Data into HTML Common Attributes
  # --------------------------------------------------------------------------------------
  # Rule #2 is for putting untrusted data into typical attribute values like
  # width, name, value, etc. This should not be used for complex attributes like
  # href, src, style, or any of the event handlers like onmouseover. It is
  # extremely important that event handler attributes should follow Rule #3 for
  # HTML JavaScript Data Values.
  #
  # <div attr=...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...>content</div>     inside UNquoted attribute
  # <div attr='...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...'>content</div>   inside single quoted attribute
  # <div attr="...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...">content</div>   inside double quoted attribute
  #
  # Except for alphanumeric characters, escape all characters with ASCII values
  # less than 256 with the &#xHH; format (or a named entity if available) to
  # prevent switching out of the attribute. The reason this rule is so broad is
  # that developers frequently leave attributes unquoted. Properly quoted
  # attributes can only be escaped with the corresponding quote. Unquoted
  # attributes can be broken out of with many characters, including [space] % *
  # + , - / ; < = > ^ and |.
  #
  # By default, this function will not double-escape the string (allow_double_escaping
  # is off by default) and should not be touched unless you REALLY know what
  # you're doing. For example, if str = "&amp;" by default nothing will be
  # escaped since it's already escaped. However, if allow_double_escaping == true
  # then the str will be escaped as "&amp;amp&#x3B;".
  def self.to_html_attr(str, allow_double_escaping = false)
    # this trick gets the Unicode code points even when using Ruby < 1.9
    chars = str.unpack('U*')
    escaped = ''
    index = 0
    while (index < chars.length)
      escaped_char = ''
      cval = chars[index]
      if (self.is_alphanum?(cval))
        escaped_char = cval.chr
      # check for illegal characters (anything less than 32 except \t, \n, or \r
      elsif (cval < 32 && cval != 9 && cval != 10 && cval != 13)
        escaped_char = '&#xfffd;'
      elsif (cval == ?& && !allow_double_escaping)
        # prevent double escaping by checking to see if this is the prefix to an
        # already escaped entity or if it's a standalone ampersand that needs to
        # be escaped
        entity = '&'
        i = index + 1
        while (i < chars.length && chars[i] != ?;)
          entity << chars[i].chr
          i = i + 1
        end
        if (chars[i] == ?;)
          entity << ';'
          i = i + 1
        end
        # if this is a prefix to a named entity then just return it untouched,
        # otherwise escape it
        if (self.to_char(entity))
          index = i - 1 # this will be incremented again at the end of the loop
          escaped_char = entity
        else
          escaped_char = '&amp;'
        end
      else
        # check if there's a defined entitiy name
        entity = HTML_ENTITIES[cval]
        if (!entity.nil?)
          escaped_char = '&' + entity + ';'
        else
          # return the hex entity (as suggested in the spec) if there is not a
          # defined entity name
          escaped_char = self.to_html_hex_entity(cval)
        end
      end
      escaped << escaped_char
      index = index + 1
    end
    escaped
  end

  # RULE #3 - JavaScript Escape Before Inserting Untrusted Data into HTML JavaScript Data Values
  # --------------------------------------------------------------------------------------------
  # Rule #3 concerns the JavaScript event handlers that are specified on various
  # HTML elements. The only safe place to put untrusted data into these event
  # handlers as a quoted "data value." Including untrusted data inside any other
  # code block is quite dangerous, as it is very easy to switch into an execution
  # context, so use with caution.
  #
  # <script>alert('...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...')</script>     inside a quoted string
  # <script>x='...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...'</script>          one side of a quoted expression
  # <div onmouseover="x='...ESCAPE UNTRUSTED DATA BEFORE PUTTING HERE...'"</div>  inside quoted event handler
  #
  # Please note there are some JavaScript functions that can never safely
  # untrusted data as input - EVEN IF JAVASCRIPT ESCAPED! For example:
  # <script>
  # window.setInterval('...EVEN IF YOU ESCAPE UNTRUSTED DATA YOU ARE XSSED HERE...');
  # </script>
  # Except for alphanumeric characters, escape all characters less than 256 with
  # the \xHH format to prevent switching out of the data value into the script
  # context or into another attribute. Do not use any escaping shortcuts like \"
  # because the quote character may be matched by the HTML attribute parser which
  # runs first. If an event handler is quoted, breaking out requires the
  # corresponding quote. The reason this rule is so broad is that developers
  # frequently leave event handler attributes unquoted. Properly quoted attributes
  # can only be escaped with the corresponding quote. Unquoted attributes can be
  # broken out of with many characters including [space] % * + , - / ; < = > ^ and |.
  # Also, a </script> closing tag will close a script block even though it is
  # inside a quoted string because the HTML parser runs before the JavaScript parser.
  def self.to_browser_json(obj)
    if (obj.kind_of?(Array))
      arr = obj.map { |element| self.to_browser_json(element) }
      json = "[" + arr.join(",") + "]"
    else
      if (!obj.kind_of?(String))
        raise ArgumentError, "to_browser_json only supports strings and arrays (of arrays or strings)", caller
      end
      self.to_js_string(obj.to_s, '"')
    end
  end

  def self.to_js_string(str, quote_char = nil)
    # this trick gets the Unicode code points even when using Ruby < 1.9
    chars = str.unpack('U*')
    escaped = chars.map do |cval|
      if (self.is_alphanum?(cval))
        cval.chr
      else
        hex_str = cval.to_s(16).upcase
        if (cval < 256)
          '\x' + hex_str.rjust(2, '0')
        else
          '\u' + hex_str.rjust(4, '0')
        end
      end
    end
    escaped = escaped.join
    if (!quote_char.nil?)
      escaped = quote_char + escaped + quote_char
    end
    escaped
  end

private

  def self.is_alphanum?(c)
    # 0 - 9
    (c >= 48 && c <= 57) ||
    # A - Z
    (c >= 65 && c <= 90) ||
    # a - z
    (c >= 97 && c <= 122)
  end

  def self.to_html_hex_entity(cval)
    hex_str = cval.to_s(16).upcase
    if (hex_str.length <= 2)
      hex_str = hex_str.rjust(2, '0')
    elsif (hex_str.length <= 4)
      hex_str = hex_str.rjust(4, '0')
    else
      # else it must be represented as a surrogate pair
      # @see http://www.russellcottrell.com/greek/utilities/SurrogatePairCalculator.htm
      h = ((cval - 0x10000) / 0x400) + 0xd800;
      l = ((cval - 0x10000) % 0x400) + 0xdc00;
      return "&#x#{h.to_s(16)};&#x#{l.to_s(16)};"
    end
    '&#x' + hex_str + ';'
  end

  def self.to_char(html_entity)
    # strip off the leading & and trailing ;
    html_entity = html_entity[1..-1] if html_entity[0] == ?&
    html_entity = html_entity[0..-2] if html_entity[-1] == ?;

    # &#xnnnn; is a hex number and &#nnnn; is a decimal number
    if (html_entity[0] == ?#)
      if (html_entity[1, 1].downcase == 'x')
        c = html_entity[2..-1].hex
      else
        c = html_entity[1..-1].to_i
      end
    else
      c = ENTITY_TO_CHAR_MAP[html_entity]
    end
  end

  # $NOTE-jrockwood-09-22-2010:
  # This list is pulled from http://www.w3schools.com/tags/ref_entities.asp and
  # http://www.w3schools.com/tags/ref_symbols.asp. There are a few that are
  # missing from that list but are still supported: 8260 => frasl, 8465 => image,
  # 8472 => weierp, 8476 => real, 8501 => alefsym, 8656 => lArr, 8657 => uArr,
  # 8658 => rArr, 8659 => dArr, 8660 => hArr
  #
  # See http://code.google.com/p/doctype/wiki/CharacterEntities which has
  # compatibility charts for each entity and whether it works in each browser.
  # The official spec is http://www.w3.org/TR/html4/sgml/entities.html.
  #
  # Only entities that are supported by all major browsers are presented here.
  # Note: Entity names are case sensitive!
  HTML_ENTITIES = {
    # Reserved Characters in HTML
    34 => 'quot',           # " quotation mark
    38 => 'amp',            # & ampersand
#   39 => 'apos'            # ' apostrophe (does not work in IE)
    60 => 'lt',             # < less-than sign
    62 => 'gt',             # > greater-than sign

    # ISO 8859-1 Symbols
    160 => 'nbsp',          # non-breaking space
    161 => 'iexcl',         # inverted exclamation mark
    162 => 'cent',          # cent
    163 => 'pound',         # pound
    164 => 'curren',        # currency
    165 => 'yen',           # yen
    166 => 'brvbar',        # broken vertical bar
    167 => 'sect',          # section
    168 => 'uml',           # spacing diaeresis
    169 => 'copy',          # copyright
    170 => 'ordf',          # feminine ordinal indicator
    171 => 'laquo',         # angle quotation mark (left)
    172 => 'not',           # negation
    173 => 'shy',           # soft hyphen
    174 => 'reg',           # registered trademark
    175 => 'macr',          # spacing macron
    176 => 'deg',           # degree
    177 => 'plusmn',        # plus-or-minus
    178 => 'sup2',          # superscript 2
    179 => 'sup3',          # superscript 3
    180 => 'acute',         # spacing acute
    181 => 'micro',         # micro
    182 => 'para',          # paragraph
    183 => 'middot',        # middle dot
    184 => 'cedil',         # spacing cedilla
    185 => 'sup1',          # superscript 1
    186 => 'ordm',          # masculine ordinal indicator
    187 => 'raquo',         # angle quotation mark (right)
    188 => 'frac14',        # fraction 1/4
    189 => 'frac12',        # fraction 1/2
    190 => 'frac34',        # fraction 3/4
    191 => 'iquest',        # inverted question mark
    215 => 'times',         # multiplication
    247 => 'divide',        # division

    # ISO 8859-1 Characters
    192 => 'Agrave',        # capital a, grave accent
    193 => 'Aacute',        # capital a, acute accent
    194 => 'Acirc',         # capital a, circumflex accent
    195 => 'Atilde',        # capital a, tilde
    196 => 'Auml',          # capital a, umlaut mark
    197 => 'Aring',         # capital a, ring
    198 => 'AElig',         # capital ae
    199 => 'Ccedil',        # capital c, cedilla
    200 => 'Egrave',        # capital e, grave accent
    201 => 'Eacute',        # capital e, acute accent
    202 => 'Ecirc',         # capital e, circumflex accent
    203 => 'Euml',          # capital e, umlaut mark
    204 => 'Igrave',        # capital i, grave accent
    205 => 'Iacute',        # capital i, acute accent
    206 => 'Icirc',         # capital i, circumflex accent
    207 => 'Iuml',          # capital i, umlaut mark
    208 => 'ETH',           # capital eth, Icelandic
    209 => 'Ntilde',        # capital n, tilde
    210 => 'Ograve',        # capital o, grave accent
    211 => 'Oacute',        # capital o, acute accent
    212 => 'Ocirc',         # capital o, circumflex accent
    213 => 'Otilde',        # capital o, tilde
    214 => 'Ouml',          # capital o, umlaut mark
    216 => 'Oslash',        # capital o, slash
    217 => 'Ugrave',        # capital u, grave accent
    218 => 'Uacute',        # capital u, acute accent
    219 => 'Ucirc',         # capital u, circumflex accent
    220 => 'Uuml',          # capital u, umlaut mark
    221 => 'Yacute',        # capital y, acute accent
    222 => 'THORN',         # capital THORN, Icelandic
    223 => 'szlig',         # small sharp s, German
    224 => 'agrave',        # small a, grave accent
    225 => 'aacute',        # small a, acute accent
    226 => 'acirc',         # small a, circumflex accent
    227 => 'atilde',        # small a, tilde
    228 => 'auml',          # small a, umlaut mark
    229 => 'aring',         # small a, ring
    230 => 'aelig',         # small ae
    231 => 'ccedil',        # small c, cedilla
    232 => 'egrave',        # small e, grave accent
    233 => 'eacute',        # small e, acute accent
    234 => 'ecirc',         # small e, circumflex accent
    235 => 'euml',          # small e, umlaut mark
    236 => 'igrave',        # small i, grave accent
    237 => 'iacute',        # small i, acute accent
    238 => 'icirc',         # small i, circumflex accent
    239 => 'iuml',          # small i, umlaut mark
    240 => 'eth',           # small eth, Icelandic
    241 => 'ntilde',        # small n, tilde
    242 => 'ograve',        # small o, grave accent
    243 => 'oacute',        # small o, acute accent
    244 => 'ocirc',         # small o, circumflex accent
    245 => 'otilde',        # small o, tilde
    246 => 'ouml',          # small o, umlaut mark
    248 => 'oslash',        # small o, slash
    249 => 'ugrave',        # small u, grave accent
    250 => 'uacute',        # small u, acute accent
    251 => 'ucirc',         # small u, circumflex accent
    252 => 'uuml',          # small u, umlaut mark
    253 => 'yacute',        # small y, acute accent
    254 => 'thorn',         # small thorn, Icelandic
    255 => 'yuml',          # small y, umlaut mark

    # Math Symbols Supported by HTML
    8704 => 'forall',       # for all
    8706 => 'part',         # part
    8707 => 'exist',        # exists
    8709 => 'empty',        # empty
    8711 => 'nabla',        # nabla
    8712 => 'isin',         # isin
    8713 => 'notin',        # notin
    8715 => 'ni',           # ni
    8719 => 'prod',         # prod
    8721 => 'sum',          # sum
    8722 => 'minus',        # minus
    8727 => 'lowast',       # lowast
    8730 => 'radic',        # square root
    8733 => 'prop',         # proportional to
    8734 => 'infin',        # infinity
    8736 => 'ang',          # angle
    8743 => 'and',          # and
    8744 => 'or',           # or
    8745 => 'cap',          # cap
    8746 => 'cup',          # cup
    8747 => 'int',          # integral
    8756 => 'there4',       # therefore
    8764 => 'sim',          # similar to
    8773 => 'cong',         # congruent to
    8776 => 'asymp',        # almost equal
    8800 => 'ne',           # not equal
    8801 => 'equiv',        # equivalent
    8804 => 'le',           # less or equal
    8805 => 'ge',           # greater or equal
    8834 => 'sub',          # subset of
    8835 => 'sup',          # superset of
    8836 => 'nsub',         # not subset of
    8838 => 'sube',         # subset or equal
    8839 => 'supe',         # superset or equal
    8853 => 'oplus',        # circled plus
    8855 => 'otimes',       # cirled times
    8869 => 'perp',         # perpendicular
    8901 => 'sdot',         # dot operator

    # Greek Letters Supported by HTML
    913 => 'Alpha',         # Alpha
    914 => 'Beta',          # Beta
    915 => 'Gamma',         # Gamma
    916 => 'Delta',         # Delta
    917 => 'Epsilon',       # Epsilon
    918 => 'Zeta',          # Zeta
    919 => 'Eta',           # Eta
    920 => 'Theta',         # Theta
    921 => 'Iota',          # Iota
    922 => 'Kappa',         # Kappa
    923 => 'Lambda',        # Lambda
    924 => 'Mu',            # Mu
    925 => 'Nu',            # Nu
    926 => 'Xi',            # Xi
    927 => 'Omicron',       # Omicron
    928 => 'Pi',            # Pi
    929 => 'Rho',           # Rho
    #   => undefined        #   Sigmaf
    931 => 'Sigma',         # Sigma
    932 => 'Tau',           # Tau
    933 => 'Upsilon',       # Upsilon
    934 => 'Phi',           # Phi
    935 => 'Chi',           # Chi
    936 => 'Psi',           # Psi
    937 => 'Omega',         # Omega
    945 => 'alpha',         # alpha
    946 => 'beta',          # beta
    947 => 'gamma',         # gamma
    948 => 'delta',         # delta
    949 => 'epsilon',       # epsilon
    950 => 'zeta',          # zeta
    951 => 'eta',           # eta
    952 => 'theta',         # theta
    953 => 'iota',          # iota
    954 => 'kappa',         # kappa
    955 => 'lambda',        # lambda
    956 => 'mu',            # mu
    957 => 'nu',            # nu
    958 => 'xi',            # xi
    959 => 'omicron',       # omicron
    960 => 'pi',            # pi
    961 => 'rho',           # rho
    962 => 'sigmaf',        # sigmaf
    963 => 'sigma',         # sigma
    964 => 'tau',           # tau
    965 => 'upsilon',       # upsilon
    966 => 'phi',           # phi
    967 => 'chi',           # chi
    968 => 'psi',           # psi
    969 => 'omega',         # omega
    977 => 'thetasym',      # theta symbol
    978 => 'upsih',         # upsilon symbol
    982 => 'piv',           # pi symbol

    # Other Entities Supported by HTML
    338  => 'OElig',        # capital ligature OE
    339  => 'oelig',        # small ligature oe
    352  => 'Scaron',       # capital S with caron
    353  => 'scaron',       # small S with caron
    376  => 'Yuml',         # capital Y with diaeres
    402  => 'fnof',         # f with hook
    710  => 'circ',         # modifier letter circumflex accent
    732  => 'tilde',        # small tilde
    8194 => 'ensp',         # en space
    8195 => 'emsp',         # em space
    8201 => 'thinsp',       # thin space
    8204 => 'zwnj',         # zero width non-joiner
    8205 => 'zwj',          # zero width joiner
    8206 => 'lrm',          # left-to-right mark
    8207 => 'rlm',          # right-to-left mark
    8211 => 'ndash',        # en dash
    8212 => 'mdash',        # em dash
    8216 => 'lsquo',        # left single quotation mark
    8217 => 'rsquo',        # right single quotation mark
    8218 => 'sbquo',        # single low-9 quotation mark
    8220 => 'ldquo',        # left double quotation mark
    8221 => 'rdquo',        # right double quotation mark
    8222 => 'bdquo',        # double low-9 quotation mark
    8224 => 'dagger',       # dagger
    8225 => 'Dagger',       # double dagger
    8226 => 'bull',         # bullet
    8230 => 'hellip',       # horizontal ellipsis
    8240 => 'permil',       # per mille
    8242 => 'prime',        # minutes
    8243 => 'Prime',        # seconds
    8249 => 'lsaquo',       # single left angle quotation
    8250 => 'rsaquo',       # single right angle quotation
    8254 => 'oline',        # overline
    8260 => 'frasl',        # fraction slash
    8364 => 'euro',         # euro
    8465 => 'image',        # blackletter capital I = imaginary part
    8472 => 'weierp',       # script capital P = power set = Weierstrass p
    8476 => 'real',         # black-letter capital R = real part symbol
    8482 => 'trade',        # trademark
    8501 => 'alefsym',      # alef symbol
    8592 => 'larr',         # left arrow
    8593 => 'uarr',         # up arrow
    8594 => 'rarr',         # right arrow
    8595 => 'darr',         # down arrow
    8596 => 'harr',         # left right arrow
    8629 => 'crarr',        # carriage return arrow
    8656 => 'lArr',         # leftwards double arrow
    8657 => 'uArr',         # upwards double arrow
    8658 => 'rArr',         # rightwards double arrow
    8659 => 'dArr',         # downwards double arrow
    8660 => 'hArr',         # left right double arrow
    8968 => 'lceil',        # left ceiling
    8969 => 'rceil',        # right ceiling
    8970 => 'lfloor',       # left floor
    8971 => 'rfloor',       # right floor
    9674 => 'loz',          # lozenge
    9824 => 'spades',       # spade
    9827 => 'clubs',        # club
    9829 => 'hearts',       # heart
    9830 => 'diams'         # diamond
  }

  ENTITY_TO_CHAR_MAP = HTML_ENTITIES.invert

end
