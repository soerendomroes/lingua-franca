package org.lflang.generator;

import java.io.IOException;

import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.generator.IFileSystemAccess2;
import org.eclipse.xtext.generator.IGeneratorContext;
import org.lflang.FileConfig;

public class TypeScriptFileConfig extends FileConfig {

    /**
     * Custom FileConfig for the TypeScript target.
     * 
     * A TypeScript project has the generated sources in an extra `src`
     * directory. A subsequent compilation step, carried out by Babel,
     * transpiles the TypeScript sources into JavaScript code, which will be put
     * in a `dist` directory.
     * 
     * @param resource The resource that is being compiled.
     * @param fsa      Abstract file access object.
     * @param context  Context passed from the IDE or stand-alone
     *                 implementation.
     * @throws IOException
     */
    public TypeScriptFileConfig(Resource resource, IFileSystemAccess2 fsa,
            IGeneratorContext context) throws IOException {
        super(resource, fsa, context);
        this.srcGenPath = this.srcGenPath.resolve("src");
    }

}
