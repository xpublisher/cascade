<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  xmlns:cat="urn:oasis:names:tc:entity:xmlns:xml:catalog"
  xmlns:tr="http://transpect.io" 
  version="3.0"
  exclude-result-prefixes="xs cat tr">

  <xsl:import href="http://transpect.io/xslt-util/xslt-based-catalog-resolver/xsl/resolve-uri-by-catalog.xsl"/>
  <xsl:import href="http://transpect.io/xslt-util/resolve-uri/xsl/resolve-uri.xsl"/>
  <xsl:param name="cat:missing-next-catalogs-warning" as="xs:string" select="'no'"/>
  <xsl:param name="collection-uri" as="xs:string?" select="()"/>
  
  <!-- Calculate a set of parameters for subsequent XProc steps / XSLT transformations.
    The parameters are the URLs of the directories where the tool looks for customized
    settings data (XProc pipelines, XSLT, Schematron, …) for the configuration cascade.
    
    See a description of the configuration file in 
    https://github.com/transpect/cascade/blob/master/schema/cascade.rng
    
    See a description of the invocation parameters (file, clades) in 
    https://github.com/transpect/cascade/blob/master/xpl/paths.xpl
    
    If the XML catalog includes (the local copy of) 
    https://github.com/transpect/cascade/blob/master/xmlcatalog/catalog.xml,
    this XSLT may be imported by its canonical URL, which is 
    http://transpect.io/cascade/xsl/paths.xsl
    
    Functions or templates can be overwritten in your project-specific paths.xsl, 
    the location of which can be given in /Q{http://transpect.io}conf/@paths-xsl-uri
    in the transpect configuration file.
    It can be a canonical URI such as http://this.transpect.io/a9s/common/xsl/paths.xsl
    that can be resolved by the project’s catalog.
    
    The primary customization points are the functions
    
    tr:parse-file-name(): Implements your naming conventions. It typically emits
      attributes like publisher="acme", series="LNAS", work="4168", but also for the sake
      of convenience for other functions, ext="idml" (example), the input file extension(s).
    tr:target-subdir(): Maps file extensions to the subdirs below the content dir
      where they will be stored in the content repo (e.g., 'png' → 'images')
    tr:target-base-name(): Base name of the target (content repo) file. Default:
      original base name
    As a second input document, the result of calling svn info -\-xml may be supplied.
    It will be used for the param named transpect-project-uri.

    In order to include parameters that are passed by the invoking pipeline, the c:param-set document
    of this pipeline is passed to this xsl as the 3rd source document. 
    It will include this param-set’s parameters in the result document (unless these parameters
    have been newly created with possibly different values by this xsl).

    In addition to the XProc steps, there is also an XQuery front-end in the directory cascade/xquery.
    It needs to run in a BaseX that has a) a Saxon Jar in lib/custom and b) scripts that set the
    CATALOG (BaseX 10+) or the CATFILE (BaseX 9.x) option like this:

    CATFILE=xmlcatalog/catalog.xml
    exec java -Dorg.basex.CATALOG=$CATFILE -cp "$CP" $BASEX_JVM org.basex.BaseX "$@"

    This relative catalog location works if the basex directory is in the project directory 
    (for example, an svn external that points to https://subversion.le-tex.de/common/basex10/)
    that also contains the project’s xmlcatalog/catalog.xml, and if the BaseX start script
    is invoked from the project directory.

  -->

  <!-- These parameters need to be given only if this stylesheet is used for
    emitting a <c:param-set>. If it is used as a function library, the parameters
    are passed with each function call. The function params (incidentally)
    have the same name as the stylesheet params. -->
  <xsl:param name="debug" as="xs:string?" select="'no'"/>
  <xsl:param name="debug-dir-uri" as="xs:string?" select="'debug'"/>
  <xsl:param name="status-dir-uri" as="xs:string?" select="'status'"/>
  <xsl:param name="interface-language" as="xs:string?"/>

  <!-- A comma and/or whitespace separated string containing name=value pairs
  that specify the clade that a given content item belongs to -->
  <xsl:param name="clades" as="xs:string?"/>

  <xsl:param name="file" as="xs:string?"/>
  <xsl:param name="cwd" as="xs:string?"/>
  <xsl:param name="pipeline" as="xs:string?"/><!-- of declarative use only; will probably not be used when processing the content -->
  <xsl:param name="progress" as="xs:string?"/>
  <xsl:param name="progress-to-stdout" as="xs:string?"/>
  <xsl:param name="all-atts-as-params" as="xs:boolean" select="false()"/>

  <xsl:output indent="yes"/>

  <xsl:variable name="tr:conf" select="/tr:conf"/>

  <xsl:variable name="tr:conf-content-base-uri" select="/tr:conf/@content-base-uri"/>

  <xsl:variable name="tr:adaptations-path" as="xs:string" 
    select="'http://this.transpect.io/a9s/'"/>
  
  <xsl:variable name="tr:common-path" as="xs:string" 
    select="'http://this.transpect.io/a9s/common/'"/>

  <xsl:variable name="tr:catalog" as="document-node(element(cat:catalog))" 
    select="document('http://this.transpect.io/xmlcatalog/catalog.xml')"/>

  <xsl:variable name="tr:single-file-content" as="element(tr:content)">
    <!-- content-base-uri will be like: file:/path/to/idml/file.idml → file:/path/to/ --> 
    <content xmlns="http://transpect.io" content-base-uri="{replace($file, '^((.+/)([^/]+/))?.+$', '$2')}" role="work"
      name-regex="\.+" name="{replace($file, '^(.+/)?([^.]+)(\..+)?$', '$2')}" base="{tr:basename($file)}"
      ext="{tr:ext($file)}" stack-pos="1"/>
  </xsl:variable>
  
  <xsl:variable name="parse-clades-string" as="attribute(*)*" select="tr:parse-clades-string($clades)"/>
  <xsl:variable name="parse-file-name" as="attribute(*)*" select="tr:parse-file-name($file)"/>
  <xsl:variable name="all-atts" as="attribute(*)*" 
    select="$parse-clades-string,
            $parse-file-name[not(name() = $parse-clades-string/name())]" />

  <xsl:template match="* | @*" mode="tr:expand-same-as tr:prequalify-matching-clades tr:conf-filter tr:expand-placeholders">
    <xsl:copy>
      <xsl:apply-templates select="@*, *" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/">
    <xsl:if test="$parse-file-name[name() = 'base'][matches(., '^file:')]">
      <xsl:message select="'WARNING: ', string($parse-file-name[name() = 'base']), ' is not a base name, but a full uri. Please check your tr:parse-file-name() override.'"/>
    </xsl:if>
    <xsl:if test="not(/*/self::tr:conf)">
      <xsl:message select="'Empty or no conf element. Please supply a transpect configuration file.'" terminate="yes"/>
    </xsl:if>
    <xsl:variable name="expand-same-as" as="document-node(element(tr:conf))">
      <xsl:document>
        <xsl:apply-templates select="/" mode="tr:expand-same-as"/>
      </xsl:document>
    </xsl:variable>
    <xsl:variable name="prequalify-matching-clades" as="element(tr:conf)">
      <xsl:apply-templates select="$expand-same-as" mode="tr:prequalify-matching-clades">
        <xsl:with-param name="clade-name-value-pairs" as="attribute(*)*" tunnel="yes">
          <!-- If a parameter exists in the clades string, it has precedence over a parameter with the same name
          that is derived from the file name. Please note that the <em>role</em> of a clade will translate to the 
          <em>name()</em> of an attribute, while the attribute value corresponds to the name of a clade. -->
          <xsl:sequence select="$all-atts"/>
        </xsl:with-param>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:result-document href="cascade/1_prequalify-matching-clades.xml">
      <xsl:sequence select="$prequalify-matching-clades"/>
    </xsl:result-document>
    <xsl:variable name="matching-clades-candidates" as="element(tr:clade)*"
      select="$prequalify-matching-clades//tr:clade[@name]
                                                   [tr:content[@matches = 'maybe']]
                                                   [every $a in ancestor-or-self::tr:clade[@name] satisfies ($a/@matches = 'maybe')]
                                                   [some $d in descendant::tr:content[every $a in (ancestor::tr:clade intersect current())
                                                                                      satisfies $a/@matches = 'maybe']
                                                    satisfies ($d/@matches = 'maybe')]"/>
    <!-- This will select only the most specifically matching candidates: -->
    <xsl:variable name="almost-matching-clades" as="element(tr:clade)*"
      select="$matching-clades-candidates[empty(descendant::tr:clade intersect $matching-clades-candidates)]"/>
    <!-- The remaining clades may be pl=Psy/pl=PsyLB/ext=docx and pl=Psy/ext=docx. We’ll pick the most deeply nested. -->
    <xsl:variable name="matching-clades" as="element(tr:clade)*"
      select="$almost-matching-clades[count(ancestor::*) = max(for $a in $almost-matching-clades return count($a/ancestor::*))]"/>
    <xsl:choose>
      <xsl:when test="count($matching-clades) = 0 and $file">
        <xsl:apply-templates mode="tr:create-paths-doc" select="$tr:single-file-content">
          <xsl:with-param name="matching-clades" select="$matching-clades" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="count($matching-clades) = 0">
        <xsl:message terminate="yes" select="'No path document could be generated. Please check your configuration and/or clades parameter.'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="count($matching-clades) gt 1">
          <xsl:message select="'Multiple configuration items matched: ', 
                                for $m in $matching-clades return concat(string-join($m/ancestor-or-self::tr:clade/@name, '/'), ' '), ' Processing the first one.'"/>
        </xsl:if>
        <xsl:variable name="filter-matching-clades" as="element(tr:clade)*">
          <xsl:apply-templates select="$matching-clades[1]/ancestor-or-self::tr:clade[last()]" mode="tr:conf-filter">
            <xsl:with-param name="restricted-to" tunnel="yes"
              select="$matching-clades[1]/ancestor-or-self::tr:clade"/>
            <xsl:with-param name="matching-clade" select="$matching-clades[1]" tunnel="yes"/>
            <xsl:with-param name="content-base-uri" select="$tr:conf-content-base-uri" tunnel="yes"/>
            <xsl:with-param name="code-base-uri" select="$tr:adaptations-path" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:result-document href="cascade/2_conf-filter.xml">
          <xsl:sequence select="$filter-matching-clades"/>  
        </xsl:result-document>
        <xsl:apply-templates select="$filter-matching-clades[1]" mode="tr:create-paths-doc">
          <xsl:with-param name="matching-clades" select="$matching-clades" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tr:same-as" mode="tr:expand-same-as">
    <!-- The schematron in cascade.rng will throw an error if @clade does not point to
         a single clade (other than the parent clade of the current same-as element) -->
    <xsl:variable name="referenced-clade" as="element(tr:clade)" 
      select="//tr:clade[@name = current()/@clade][@role = current()/../@role][not(. is current()/..)]"/>
    <xsl:copy-of select="$referenced-clade/*[empty(self::tr:param)]"/>
  </xsl:template>

  <!--<xsl:template match="/" priority="2">
    <xsl:variable name="out" as="node()*">
      <xsl:next-match/>
    </xsl:variable>
    <xsl:message select="'OOOOOOOOOOOOOOOOO ', $out"/>
    <xsl:sequence select="$out"/>
  </xsl:template>-->


  <xsl:function name="tr:diagnostic-string" as="xs:string?">
    <xsl:param name="atts" as="attribute(*)*"/>
    <xsl:variable name="prelim" as="attribute(*)*">
      <xsl:perform-sort>
        <xsl:sort select="name()"/>
        <xsl:sequence select="$atts"/>
      </xsl:perform-sort>
    </xsl:variable>
    <xsl:sequence select="string-join(for $a in $prelim return concat(name($a), '=', $a), ' ')"/>
  </xsl:function>

  <xsl:template match="/*" mode="tr:prequalify-matching-clades">
    <xsl:param name="clade-name-value-pairs" as="attribute(*)*" tunnel="yes"/>
    <xsl:copy>
      <xsl:sequence select="$clade-name-value-pairs"/>
      <xsl:apply-templates select="@*, *" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tr:clade | tr:content" mode="tr:prequalify-matching-clades">
    <xsl:param name="clade-name-value-pairs" as="attribute(*)*" tunnel="yes"/>
    <xsl:copy>
      <xsl:choose>
        <xsl:when test="some $nvp in $clade-name-value-pairs
                        satisfies (
                          (name($nvp) = self::tr:clade/@role 
                           and not(string($nvp) = @name) 
                           and not(if (self::tr:clade/@name-regex) then matches(string($nvp),self::tr:clade/@name-regex) else false())
                           and not(some $d in descendant::tr:clade 
                                   satisfies (name($nvp) = $d/@role))))">
          <!-- There is no clade of the same role below, and this clade’s name or name-regex does not match. -->
        </xsl:when>
        <xsl:when test="exists(current()/@name-regex)
                        and exists($clade-name-value-pairs[name() = current()/@role][matches(., string(current()/@name-regex))])">
          <xsl:attribute name="matches" select="'maybe'"/>
          <xsl:attribute name="name" select="$clade-name-value-pairs[name() = current()/@role][matches(., current()/@name-regex)]"/>
        </xsl:when>
        <xsl:when test="exists(current()/@name-regex)
                        and exists($clade-name-value-pairs[name() = current()/@role][not(matches(., string(current()/@name-regex)))])">
          <xsl:attribute name="matches" select="'false'"/>
        </xsl:when>
        <xsl:when test="some $ds in descendant-or-self::tr:clade 
                        satisfies (exists($clade-name-value-pairs[name() = $ds/@role][. = ($ds/@file-name-component, $ds/@name)]))">
          <xsl:attribute name="matches" select="'maybe'"/>
        </xsl:when>
        <xsl:when test="not(exists(current()/(@name | @name-regex)))
                        and exists($clade-name-value-pairs[name() = current()/@role])">
          <xsl:attribute name="matches" select="'maybe'"/>
          <xsl:attribute name="name" select="$clade-name-value-pairs[name() = current()/@role]"/>
        </xsl:when>
      </xsl:choose>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:apply-templates select="parent::tr:cascade/tr:param[not(@name = current()/tr:param/@name)]" mode="#current">
        <!-- default parameters -->
      </xsl:apply-templates>
      <xsl:apply-templates select="*" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  

  <xsl:template match="*[not(@matches = ('true', 'maybe'))]" mode="tr:conf-filter" priority="2"/>

  <xsl:template match="tr:clade[@matches = ('true', 'maybe')]/@matches" mode="tr:conf-filter">
    <xsl:attribute name="matches" select="'true'"/>
  </xsl:template>

  <xsl:template match="tr:param" mode="tr:conf-filter" priority="3">
    <xsl:copy-of select="."/>
  </xsl:template>

  <xsl:template match="tr:clade" mode="tr:conf-filter">
    <xsl:param name="content-base-uri" as="xs:string" tunnel="yes"/>
    <xsl:param name="code-base-uri" as="xs:string" tunnel="yes"/>
    <xsl:param name="restricted-to" as="element(*)+" tunnel="yes"/>
    <xsl:param name="matching-clade" as="element(tr:clade)" tunnel="yes"/>
    <xsl:if test=". intersect $restricted-to">
      <xsl:variable name="new-content-base-uri" as="xs:string" 
        select="tr:uri-composer(concat($content-base-uri, @name, '/'), concat(@content-base-uri, '/'))"/>
      <xsl:variable name="new-code-base-uri" as="xs:string" select="(concat(replace($code-base-uri, '/+$', ''), '/', @name, '/'), @code-base-uri)[last()]"/>
      <xsl:copy>
        <xsl:attribute name="stack-pos" 
          select="count(descendant-or-self::tr:clade[exists(. intersect $matching-clade/ancestor-or-self::*)])
                  + count($matching-clade/descendant::tr:content[@matches = ('true', 'maybe')]
                                                                       [every $c in ancestor::tr:clade satisfies ($c/@matches = ('true', 'maybe'))])"/>
        <xsl:attribute name="content-base-uri" select="$new-content-base-uri"/>
        <xsl:attribute name="code-base-uri" select="$new-code-base-uri"/>
        <xsl:apply-templates select="@* except @content-base-uri, 
                                     node()" mode="#current">
          <xsl:with-param name="content-base-uri" select="$new-content-base-uri" tunnel="yes"/>
          <xsl:with-param name="code-base-uri" select="$new-code-base-uri" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="tr:content" mode="tr:conf-filter">
    <xsl:param name="matching-clade" tunnel="yes" as="element(tr:clade)"/>
    <xsl:param name="content-base-uri" as="xs:string" tunnel="yes"/>
    <xsl:if test="exists($matching-clade//* intersect .)">
      <xsl:variable name="new-content-base-uri" as="xs:string" 
        select="tr:uri-composer(concat($content-base-uri, @name, '/'), concat(@content-base-uri, '/'))"/>
      <xsl:copy>
        <xsl:attribute name="stack-pos" select="count(descendant-or-self::tr:content[@matches = ('true', 'maybe')])"/>
        <xsl:copy-of select="ancestor::*[last()]/(@* except @content-base-uri)"/>
        <xsl:attribute name="content-base-uri" select="$new-content-base-uri"/>
        <xsl:apply-templates select="@* except @content-base-uri, node()" mode="#current">
          <xsl:with-param name="content-base-uri" select="$new-content-base-uri" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="tr:clade[not(parent::*)] | tr:content[not(parent::*)]" mode="tr:create-paths-doc">
    <xsl:param name="matching-clades" as="element(tr:clade)*" tunnel="yes"/>
    <c:param-set>
      <xsl:variable name="prelim" as="element(c:param)+">
        <c:param name="matching-clades" value="{count($matching-clades)}"/>
        <!-- s9y is for 'specificity' -->
        <xsl:variable name="s9y" select="xs:integer(@stack-pos) + 1" as="xs:integer"/>
        <c:param name="s9y{$s9y}-role" value="common"/>
        <c:param name="s9y{$s9y}-path-canonical" value="{tr:reverse-resolve-uri-by-catalog($tr:common-path, $tr:catalog)}"/>
        <c:param name="s9y{$s9y}-path" value="{tr:resolve-uri-by-catalog($tr:common-path, $tr:catalog)}"/>
        <xsl:next-match/>
        <xsl:call-template name="tr:other-params"/>
      </xsl:variable>
      <!-- These are the command line overrides: -->
      <xsl:variable name="param-document-params" as="element(c:param)*" select="collection($collection-uri)/c:param-set/c:param"/>
      <!-- These are global, clade-independent params in the config: -->
      <xsl:variable name="global-config-params" as="element(c:param)*">
        <xsl:apply-templates select="collection($collection-uri)/tr:conf/tr:cascade/tr:param[not(@name = $param-document-params/@name)]" mode="tr:create-paths-doc"/>  
      </xsl:variable>
      <xsl:variable name="prelim2" as="element(c:param)+">
        <xsl:for-each-group select="$prelim[not(@name = $param-document-params/@name)], $param-document-params, $global-config-params" group-by="@name">
          <xsl:sort select="@name"/>
          <xsl:sequence select="current-group()[last()]"/>
        </xsl:for-each-group>  
      </xsl:variable>
      <xsl:apply-templates select="$prelim2" mode="tr:expand-placeholders">
        <xsl:with-param name="all-params" as="element(c:param)+" select="$prelim2" tunnel="yes"/>
      </xsl:apply-templates>
    </c:param-set>
  </xsl:template>
  
  <xsl:template match="c:param[contains(@value, '{$')]" mode="tr:expand-placeholders">
    <xsl:param name="all-params" as="element(c:param)+" tunnel="yes"/>
    <xsl:variable name="placeholder-regex" as="xs:string" select="'\{\$([^\}]+)\}'"/>
    <xsl:copy>
      <xsl:apply-templates select="@name" mode="#current"/>
      <xsl:attribute name="value" separator="">
        <xsl:variable name="prelim" as="xs:string+">
          <xsl:analyze-string select="@value" regex="{$placeholder-regex}">
            <xsl:matching-substring>
              <xsl:sequence select="string($all-params[@name = regex-group(1)]/@value)"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
              <xsl:sequence select="."/>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
        </xsl:variable>
        <xsl:variable name="function-placeholder-regex" as="xs:string" select="'!\s*(\i\c+:\i\c+)\s*\(([^,]+(,[^,]+)*)\)'"/>
        <xsl:sequence select="string-join($prelim, '')" 
          use-when="xs:decimal(system-property('xsl:version')) lt 3.0
                    or 
                    not(system-property('xsl:supports-higher-order-functions') = 'yes')"/>
        <xsl:analyze-string select="string-join($prelim)" regex="{$function-placeholder-regex}" 
          use-when="xs:decimal(system-property('xsl:version')) ge 3.0
                    and
                    system-property('xsl:supports-higher-order-functions') = 'yes'">
            <xsl:matching-substring>
              <!-- This is not a proper parser! Values (after placeholder expansion) will be treated as strings, and they will be whitespace-normalized. 
                Omit single or double quotes around the arguments lest they become part of the string arguments. 
                All commas, even when contained in placeholder expansion strings, will be treated as argument separators. --> 
              <xsl:variable name="args" as="xs:string+" select="tokenize(regex-group(2), ',') ! normalize-space()"/>
              <xsl:sequence select="function-lookup(xs:QName(regex-group(1)), 1)($args)"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
              <xsl:value-of select="."/>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
      </xsl:attribute>
    </xsl:copy>
  </xsl:template>
  
  <xsl:function name="tr:floor" as="xs:string">
    <xsl:param name="name-and-module" as="item()+"/>
    <xsl:variable name="name" select="$name-and-module[1]"/>
    <xsl:variable name="modulo" select="for $nam in $name-and-module[2] return xs:integer($nam)"/>
    <xsl:variable name="prelim" as="xs:string+">
      <xsl:analyze-string select="$name" regex="\D+0*">
        <xsl:matching-substring>
          <xsl:sequence select="."/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:value-of select="string((xs:integer(.) idiv $modulo) * $modulo)"/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>  
    </xsl:variable>    
    <xsl:sequence select="string-join($prelim, '')"/>
  </xsl:function>
  
  <xsl:template match="tr:clade | tr:content" mode="tr:create-paths-doc">
    <xsl:variable name="s9y" as="xs:integer" select="@stack-pos"/>
    <!-- we called that adaption instead of adaptation, but we won’t call it specifity instead of specificity -->
    <c:param name="s9y{$s9y}-role" value="{@role}"/>
    <xsl:variable name="path" as="xs:string" 
      select="if (self::tr:content) 
              then @content-base-uri
              else @code-base-uri"/>
    <c:param name="s9y{$s9y}-path" value="{tr:resolve-uri-by-catalog($path, $tr:catalog)}"/>
    <c:param name="s9y{$s9y}-path-canonical" value="{tr:reverse-resolve-uri-by-catalog($path, $tr:catalog)}"/>
    <c:param name="s9y{$s9y}" value="{@name}"/>
    <xsl:if test="$s9y = 1">
      <xsl:variable name="href" select="tr:href-by-content-clade(.)" as="xs:string"/>
      <xsl:variable name="local-dir-href" as="xs:string?" select="tr:resolve-uri-by-catalog($path, $tr:catalog)"/>
      <xsl:variable name="content-dir-overrides" as="xs:string" select="replace($local-dir-href, '^(.+?)(/+)?$', '$1/override-params.xml')"/>
      <c:param name="repo-href-local" value="{tr:resolve-uri-by-catalog($href, $tr:catalog)}"/>
      <c:param name="repo-href-canonical" value="{$href}"/>
      <xsl:if test="doc-available($content-dir-overrides)">
        <xsl:for-each select="doc($content-dir-overrides)/c:param-set/c:param">
          <xsl:copy>
            <xsl:copy-of select="@*, node()"/>
              <xsl:comment select="'Loaded from content-specific override file ', $content-dir-overrides, ':'"/>
          </xsl:copy>
        </xsl:for-each>
      </xsl:if>
    </xsl:if>
    <xsl:apply-templates select="tr:param | tr:clade | tr:content" mode="#current"/>
  </xsl:template>

  <!-- Computes the repository URI of an uploaded file, after it has been determined which clade it belongs to. -->
  <xsl:function name="tr:href-by-content-clade" as="xs:string">
    <xsl:param name="content" as="element(tr:content)"/>
    <xsl:variable name="target-subdir" as="xs:string" select="tr:target-subdir($content)"/>
    <xsl:sequence select="concat($content/@content-base-uri, $target-subdir, '/'[normalize-space($target-subdir)], string-join((tr:target-base-name($content), $content/@ext[normalize-space()]), '.'))"/>
  </xsl:function>

  <xsl:function name="tr:target-base-name" as="xs:string">
    <xsl:param name="content" as="element(tr:content)"/>
    <xsl:sequence select="$content/@base"/>
  </xsl:function>
  
  <xsl:function name="tr:target-subdir" as="xs:string">
    <xsl:param name="content" as="element(tr:content)"/>
    <xsl:apply-templates select="$content/@ext" mode="tr:ext-to-target-subdir"/>
  </xsl:function>

  <xsl:template match="@ext" mode="tr:ext-to-target-subdir">
    <xsl:sequence select="string(.)"/>
  </xsl:template>

  <xsl:template match="@ext[. = ('png', 'jpg', 'jpeg')]" mode="tr:ext-to-target-subdir">
    <xsl:sequence select="if (../@base[matches(., '_COVER$')]) then 'images/cover' else 'images'"/>
  </xsl:template>

  <xsl:template match="@ext[. = 'report.xhtml']" mode="tr:ext-to-target-subdir">
    <xsl:sequence select="'report'"/>
  </xsl:template>
  
  <xsl:template match="@ext[. = 'indb.xml']" mode="tr:ext-to-target-subdir">
    <xsl:sequence select="'idml'"/>
  </xsl:template>
  
  <xsl:template match="@ext[. = 'mobi']" mode="tr:ext-to-target-subdir">
    <xsl:sequence select="'epub'"/>
  </xsl:template>


  <xsl:template match="tr:param" mode="tr:create-paths-doc">
    <c:param>
      <xsl:copy-of select="@*"/>
    </c:param>
  </xsl:template>

  <xsl:variable name="tr:clades-token-regex" select="'^([a-zA-Z][-a-zA-Z0-9]+)[=_]([-.a-zA-Z0-9~_]+)$'" as="xs:string"/>

  <xsl:function name="tr:parse-clades-string" as="attribute(*)*">
    <xsl:param name="input" as="xs:string?"/>
    <!-- e.g., 'production-line=default,work=00429, chapter=02' -->
    <xsl:for-each select="tokenize($input, '[,/\s+]')[normalize-space()]">
      <xsl:analyze-string select="." regex="{$tr:clades-token-regex}">
        <xsl:matching-substring>
          <xsl:attribute name="{regex-group(1)}" select="regex-group(2)"/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:message
            select="concat('A clade name=value token must match the regular expression ''', $tr:clades-token-regex, '''', '. Found: ''', ., '''')"
          />
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="tr:parse-file-name" as="attribute(*)*">
    <xsl:param name="filename" as="xs:string?"/>
    <xsl:variable name="basename" select="tr:basename($filename)"/>
    <xsl:analyze-string select="$basename" regex="^([^_]+?)_([^_]+?)_(.+)$">
      <xsl:matching-substring>
        <!-- 'publisher', 'series', and 'work' are merely examples for clade roles. Override this 
          function in an importing XSLT that is specific to your workflow. -->
        <xsl:attribute name="publisher" select="regex-group(1)"/>
        <xsl:attribute name="series" select="regex-group(3)"/>
        <xsl:attribute name="work" select="replace(regex-group(2), '(-.+)$', '')"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:attribute name="work" select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
    <xsl:attribute name="ext" select="tr:ext($filename)"/>
    <xsl:attribute name="base" select="$basename"/>
  </xsl:function>

  <xsl:function name="tr:base-ext" as="xs:string+">
    <xsl:param name="filename" as="xs:string"/>
    <!-- expected input: file uris or relative names, ending in, for example:
      …/foo.bar.baz, …/foo., …/foo.bar, …/foo.bar/  
    Output for the examples, in the form ('basename', 'ext'):
      ('foo', 'bar.baz'), ('foo.', ''), ('foo', 'bar'), ('foo', 'bar') --> 
    <xsl:analyze-string select="tokenize($filename, '/')[normalize-space()][last()]" regex="^(.+?)\.(.+)$">
      <xsl:matching-substring>
        <xsl:sequence select="regex-group(1), regex-group(2)"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:sequence select="., ''"/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="tr:basename" as="xs:string">
    <xsl:param name="filename" as="xs:string"/>
    <xsl:sequence select="tr:base-ext($filename)[1]"/>
  </xsl:function>

  <xsl:function name="tr:ext" as="xs:string?">
    <xsl:param name="filename" as="xs:string"/>
    <xsl:variable name="ext" as="xs:string?" select="tr:base-ext($filename)[2]"/>
    <xsl:if test="not(normalize-space($ext))">
      <xsl:message select="'Empty tr:ext() result for ''', $filename, ''''"/>
    </xsl:if>
    <xsl:sequence select="$ext"/>
  </xsl:function>

  <xsl:variable name="tr:other-params" as="element(c:param)+">
    <!-- Disable XSLT-based debugging (whether XProc-based debugging takes place is determined by the XProc debug option, not by a param): -->
    <c:param name="debug" value="'no'"/>
    <c:param name="debug-dir-uri" value="{$debug-dir-uri}"/>
    <c:param name="status-dir-uri" value="{$status-dir-uri}"/>
    <c:param name="pipeline" value="{$pipeline}"/>
    <c:param name="_params-given-in-clades-string" value="{tr:diagnostic-string($parse-clades-string)}"/>
    <c:param name="_params-given" value="{tr:diagnostic-string($all-atts)}"/>
    <c:param name="_params-from-filename-parsing" value="{tr:diagnostic-string($parse-file-name)}"/>
    <!-- svn: -->
    <c:param name="transpect-project-uri"
      value="{if (collection($collection-uri)/info/entry) then string-join((collection($collection-uri)/info/entry[1]/url, collection($collection-uri)/info/entry[1]/commit/@revision), '?p=') else ''}"/>
    <c:param name="transpect-project-revision"
      value="{if (collection($collection-uri)/info/entry/commit) then collection($collection-uri)/info/entry[1]/commit/@revision else ''}"/>
    <c:param name="transpect-project-timestamp"
      value="{if (collection($collection-uri)/info/entry/commit) then collection($collection-uri)/info/entry[1]/commit/date else ''}"/>
    <c:param name="progress" value="{$progress}"/>
    <c:param name="progress-to-stdout" value="{$progress-to-stdout}"/>
    <xsl:if test="$interface-language">
      <c:param name="interface-language" value="{$interface-language}"/>
    </xsl:if>
    <!-- If no file was given (that is, only clades were given instead), we do not try to synthesize a file name 
      from the clade components. A file name cannot deterministically be synthesized when a pipeline may accept 
      any of certain types of input files (e.g., a .docx or an .idml) --> 
    <xsl:if test="$file">
      <c:param name="file" value="{$file}"/>
      <c:param name="ext" value="{($all-atts[name() = 'ext'], tr:ext($file))[1]}"/>
      <c:param name="basename" value="{tr:basename($file)}"/>
    </xsl:if>
    <xsl:if test="$all-atts-as-params">
      <xsl:apply-templates select="$all-atts" mode="att-to-param"/>
    </xsl:if>
  </xsl:variable>
  
  <xsl:template match="@*" mode="att-to-param">
    <c:param name="{name()}" value="{string(.)}"/>
  </xsl:template>

  <!-- overwrite the named template in your optional project 'paths.xsl' if necessary -->
  <xsl:template name="tr:other-params">
    <xsl:sequence select="$tr:other-params"/>
  </xsl:template>

</xsl:stylesheet>
