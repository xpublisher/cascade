<?xml version="1.0" encoding="utf-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"  
  xmlns:cx="http://xmlcalabash.com/ns/extensions" 
  xmlns:cascade="http://transpect.io/cascade"
  xmlns:tr="http://transpect.io"
  version="1.0"
  name="paths"
  type="cascade:paths">
  
  <p:option name="debug" select="'no'"/>
  <p:option name="debug-dir-uri" select="'debug'"/>
  <p:option name="status-dir-uri" select="'status'"/>
  
  <p:option name="interface-language" select="'en'"/>
  <p:option name="clades" select="''"/>
  <p:option name="file" required="true"/>
  <p:option name="pipeline" select="'unknown'"/>
  <p:option name="progress" select="'no'">
    <p:documentation>Whether to display progress information as text files in a certain directory</p:documentation>
  </p:option>
  <p:option name="progress-to-stdout" required="false" select="'no'">
    <p:documentation>Whether to write progress information to console</p:documentation>
  </p:option>
  <p:option name="determine-transpect-project-version" required="false" select="'no'">
    <p:documentation xmlns="http://www.w3.org/1999/xhtml">Whether an attempt should be made (currently by running <code>svn info --xml</code>)
    to determine the svn revision of the transpect project.</p:documentation>
  </p:option>
  
  <p:input port="conf" >
    <p:document href="http://customers.transpect.io/cascade/conf/transpect-conf.xml"/>
  </p:input>
  <p:input port="stylesheet" primary="true">
    <p:documentation>The default path calculation stylesheet. Most probably you will want to define your own stylesheet for your project.
      This stylesheet will most probably import the default stylesheet.</p:documentation>
    <p:document href="../xsl/paths.xsl"/>
  </p:input>
  
  <p:output port="result" primary="true">
    <p:pipe port="result" step="try"/>  
  </p:output>
  <p:serialization port="result" omit-xml-declaration="false" indent="true"/>
  <p:output port="report" >
    <p:pipe port="report" step="try"/>
  </p:output>

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl" />
  <p:import href="http://transpect.io/xproc-util/simple-progress-msg/xpl/simple-progress-msg.xpl"/>
	<p:import href="http://transpect.io/xproc-util/file-uri/xpl/file-uri.xpl"/>
  
  <p:try name="try">
    <p:group>
      <p:output port="result" primary="true">
        <p:pipe port="result" step="xslt"/>
      </p:output>
      <p:output port="report">
        <p:inline>
          <c:ok/>
        </p:inline>
      </p:output>

      <p:choose name="svn-info">
        <p:when test="$determine-transpect-project-version = 'yes'">
          <p:output port="result" primary="true"/>
          <p:try>
            <p:group>
              <p:exec command="env" args="svn info --xml">
                <p:input port="source">
                  <p:empty/>
                </p:input>
              </p:exec>
              <p:filter select="/c:result/info"/>
            </p:group>
            <p:catch>
              <p:identity>
                <p:input port="source">
                  <p:inline>
                    <info/>
                  </p:inline>
                </p:input>
              </p:identity>
            </p:catch>
          </p:try>
        </p:when>
        <p:otherwise>
          <p:output port="result" primary="true"/>
          <p:identity>
            <p:input port="source">
              <p:inline>
                <info/>
              </p:inline>
            </p:input>
          </p:identity>
        </p:otherwise>
      </p:choose>

      <tr:file-uri name="file-uri">
        <p:with-option name="filename" select="$file"/>
      </tr:file-uri>

      <p:sink/>

      <p:xslt name="xslt">
        <p:documentation xmlns="http://www.w3.org/1999/xhtml">
          <p>The stylesheet provides one essential customization point: cascade:parse-file-name() that accepts a file uri,
            typically with an extension and a directory path. It may then analyze this filename, potentially after applying
            cascade:basename() in order to strip paths and the extension. The function produces a sequence of attributes whose
            names should correspond to clade roles and whose values should correspond to clade names.</p>
          <p>Another cutomization point is the template named 'main-file-xml'. The stylesheet parameter 'filenames' (xs:string)
            will be split at whitespace. It is supposed to output a <code>&lt;files></code> document that contains a
              <code>&lt;file for-paths="…">…&lt;/file></code> element for each of the individual filenames. The value of the
            @for-paths attribut is a regular input filename from which a paths document will be calculated. The content of the
            file element will be concatenated with the s9y1-path of the paths document in order to calculate the expected
            storage location for the input file.</p>
        </p:documentation>
        <p:with-param name="interface-language" select="$interface-language"/>
        <p:with-param name="clades" select="$clades"/>
        <p:with-param name="file" select="/*/@local-href">
          <p:pipe port="result" step="file-uri"/>
        </p:with-param>
        <p:with-param name="pipeline" select="$pipeline"/>
        <p:with-param name="debug-dir-uri" select="$debug-dir-uri"/>
        <p:with-param name="progress" select="$progress"/>
        <p:with-param name="progress-to-stdout" select="$progress-to-stdout"/>
        <p:with-param name="cwd" select="/*/@cwd">
          <p:pipe port="result" step="file-uri"/>
        </p:with-param>
        <p:input port="source">
          <p:pipe step="paths" port="conf"/>
          <p:pipe port="result" step="svn-info"/>
        </p:input>
        <p:input port="stylesheet">
          <p:pipe step="paths" port="stylesheet"/>
        </p:input>
        <p:input port="parameters">
          <p:empty/>
        </p:input>
      </p:xslt>
      <p:for-each>
        <p:iteration-source>
          <p:pipe port="secondary" step="xslt"/>
        </p:iteration-source>
        <tr:store-debug>
          <p:with-option name="pipeline-step" select="replace(base-uri(), '^.+/(paths/.+)\.xml$', '$1')"/>
          <p:with-option name="active" select="$debug"/>
          <p:with-option name="base-uri" select="$debug-dir-uri"/>
        </tr:store-debug>
      </p:for-each>
      <p:sink/>
    </p:group>
    <p:catch name="catch">
      <p:output port="result" primary="true">
        <p:pipe port="result" step="empty-params"/>
      </p:output>
      <p:output port="report">
        <p:pipe port="result" step="propagate"/>
      </p:output>
       <tr:propagate-caught-error name="propagate" msg-file="paths-error.txt" code="cascade:PATH01" severity="warning">
        <p:with-option name="status-dir-uri" select="$status-dir-uri"/>
        <p:input port="source">
          <p:pipe port="error" step="catch"/>
        </p:input>
      </tr:propagate-caught-error>
      <p:sink/>
      <p:identity name="empty-params">
        <p:input port="source">
          <p:inline>
            <c:param-set/>
          </p:inline>
        </p:input>
      </p:identity>
    </p:catch>
  </p:try>
  
  <tr:store-debug pipeline-step="paths">
    <p:with-option name="active" select="$debug" />
    <p:with-option name="base-uri" select="$debug-dir-uri" />
  </tr:store-debug>

  <p:sink/>
  
</p:declare-step>