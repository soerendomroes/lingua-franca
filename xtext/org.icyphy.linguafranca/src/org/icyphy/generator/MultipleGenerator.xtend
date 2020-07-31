/* Generator for multiple target reactors */
package org.icyphy.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import java.util.Map
import java.util.Set
import java.util.HashMap
import java.util.LinkedList
import java.io.File
import org.eclipse.emf.ecore.util.EcoreUtil
import org.icyphy.linguaFranca.Model
import org.icyphy.linguaFranca.Action
import org.icyphy.linguaFranca.VarRef
import org.icyphy.linguaFranca.Reactor
import org.icyphy.linguaFranca.LinguaFrancaFactory
import org.icyphy.InferredType
import org.icyphy.Targets

class MultipleGenerator extends GeneratorBase {
    
    new () {
        super()
        
        // set defaults for federate compilation
        this.targetCompiler = "gcc"
        this.targetCompilerFlags = "-O2"
        
        // Don't perform AST transformations
        // Do transformations in target generators
        this.skipASTTransformations = true
    }
    
    // Set of acceptable import targets is not restricted.
    val Set<String> acceptableTargetSet = null
    
    // //////////////////////////////////////////
    // // Protected methods.

    /** Return a set of targets that are acceptable to this generator.
     *  Imported files that are Lingua Franca files must specify targets
     *  in this set or an error message will be reported and the import
     *  will be ignored. The returned set is a set of case-insensitive
     *  strings specifying target names. If any target is acceptable,
     *  return null.
     */
    override acceptableTargets() {
        acceptableTargetSet
    }
    
    /** 
     *  Generate code for multiple languages from the Lingua Franca
     *  model contained by the specified resource. This is the main
     *  entry point for code generation.
     *  @param resource The resource containing the source code.
     *  @param fsa The file system access (used to write the result).
     *  @param context FIXME: Undocumented argument. No idea what this is.
     */
    override void doGenerate(
        Resource resource,
        IFileSystemAccess2 fsa,
        IGeneratorContext context
    ) {        
        super.doGenerate(resource, fsa, context)
        
        // FIXME: The CGenerator expects these paths to be
        // relative to the directory, not the project folder
        // so for now I just left it that way. A different
        // directory structure for RTI and TS code may be
        // preferable.
        var cSrcGenPath = directory + File.separator + "src-gen"
        var cOutPath = directory + File.separator + "bin"
         
        var splitModel = splitMultilingualModel(resource, targetByReactor)
        for (targetName : splitModel.keySet()) {
            var targetModel = splitModel.get(targetName)
            var targetReactors = new LinkedList<Reactor>()
            for (r : reactors) {
                if (targetByReactor.get(r).equalsIgnoreCase(targetName)  ) {
                    targetReactors.add(r)
                }
            }
            var GeneratorBase targetGenerator
            switch (Targets.get(targetName)) {
                // FIXME: No testing done for Cpp or CCpp generators so far
                case Targets.C : targetGenerator = new CGenerator()
                case Targets.CPP : targetGenerator = new CppGenerator()
                case Targets.CCpp : targetGenerator = new CCppGenerator()
                case Targets.TS : targetGenerator = new TypeScriptGenerator()
                default : throw new RuntimeException("Unknown target language generator")
            }
            targetGenerator.generateFromModel(targetModel, 
                targetReactors, resource, fsa, context
            )
        }
        
        
        // Generate the C RTI. But first, analyze
        // the federates in the original resource,
        // so the RTI will be created with the correct
        // federate topology
        analyzeFederates() 
        if (federates.length > 1) {
            
            // Create C output directories (if they don't exist)            
            var dir = new File(cSrcGenPath)
            if (!dir.exists()) dir.mkdirs()
            dir = new File(cOutPath)
            if (!dir.exists()) dir.mkdirs()
            
            createFederateRTI()

            // Copy the required library files into the target file system.
            // This will overwrite previous versions.
            var files = newArrayList("rti.c", "rti.h", "federate.c", "reactor_threaded.c", "reactor.c", "reactor_common.c", "reactor.h", "pqueue.c", "pqueue.h", "util.h", "util.c")

            for (file : files) {
                copyFileFromClassPath(
                    File.separator + "lib" + File.separator + "core" + File.separator + file,
                    cSrcGenPath + File.separator + file
                )
            }
            compileRTI()
        }
        return
    }
    
    
    /**
     * Generate code for the body of a reaction that handles input from the network
     * that is handled by the specified action. This function records the information
     * needed for generation so it may be passed to the appropriate target language
     * generator.
     * @param action The action that has been created to handle incoming messages.
     * @param sendingPort The output port providing the data to send.
     * @param receivingPort The ID of the destination port.
     * @param receivingPortID The ID of the destination port.
     * @param sendingFed The sending federate.
     * @param receivingFed The destination federate.
     * @param type The type.
     * @throws UnsupportedOperationException If the target does not support this operation.
     */
    override def String generateNetworkReceiverBody(
        Action action,
        VarRef sendingPort,
        VarRef receivingPort,
        int receivingPortID, 
        FederateInstance sendingFed,
        FederateInstance receivingFed,
        InferredType type
    ) {
        return null
    }
    
    /**
     * Generate code for the body of a reaction that handles an output
     * that is to be sent over the network. This base class throws an exception.
     * @param sendingPort The output port providing the data to send.
     * @param receivingPort The ID of the destination port.
     * @param receivingPortID The ID of the destination port.
     * @param sendingFed The sending federate.
     * @param receivingFed The destination federate.
     * @param type The type.
     * @throws UnsupportedOperationException If the target does not support this operation.
     */
    override def String generateNetworkSenderBody(
        VarRef sendingPort,
        VarRef receivingPort,
        int receivingPortID, 
        FederateInstance sendingFed,
        FederateInstance receivingFed,
        InferredType type
    ) {
        return null
    }
    
    // 
    override String generateDelayBody(Action action, VarRef port) {
        // TODO Auto-generated method stub
        return null
    }

    override String generateForwardBody(Action action, VarRef port) {
        // TODO Auto-generated method stub
        return null
    }

    override String generateDelayGeneric() {
        // TODO Auto-generated method stub
        return null
    }

    override boolean supportsGenerics() {
        // TODO Auto-generated method stub
        return false
    }

    override String getTargetTimeType() {
        // TODO Auto-generated method stub
        return null
    }

    override String getTargetUndefinedType() {
        // TODO Auto-generated method stub
        return null
    }

    override String getTargetFixedSizeListType(String baseType, Integer size) {
        // TODO Auto-generated method stub
        return null
    }

    override String getTargetVariableSizeListType(String baseType) {
        // TODO Auto-generated method stub
        return null
    }

    /**
     * Separate an LF model that contains multiple targets
     * into separate LF models, each containing only reactor classes
     * and reactor instances for a single target. 
     * @param resource The original resource from the LF code.
     * @return A Map from each target name used in the input model
     *  to a copy of the input model with all reactor classes and
     *  reactor instances not belonging to that target removed.
     */
    def Map<String, Model> splitMultilingualModel(Resource resource, Map<Reactor, String> targetByReactor) {
        
        val factory = LinguaFrancaFactory.eINSTANCE
        var Map<String, Model> modelByTarget = new HashMap<String, Model>()
        var model = null as Model
        
        for (t : resource.allContents.toIterable.filter(Model)) {
            model = t
        }
        if (model === null) {
            throw new RuntimeException("There is no model!")
        }

        for (target : targetByReactor.values) {
            // Make a clone of the original model for each target.
            // Note, EcoreUtil.copy() performs a deep copy. 
            var newModel = EcoreUtil.copy(model)
            for (reactor : newModel.reactors) {
                
                // Then prepend to the names of all reactor classes and
                // reactor instances that have a different target the special
                // string __foreignLanguage__" to indicate that they should not.
                // be generated as normal.    
                // FIXME: should this be limited to only federated reactors
                // and not main?
                if (reactor.isMain || reactor.isFederated) {
                    for (instantiation : reactor.instantiations) {
                        if (!targetByReactor.get(instantiation.reactorClass).equalsIgnoreCase(target)) {
                            instantiation.setName(foreignReactorPrefix + instantiation.getName())
                        }
                    }
                } else {
                    var targetOfReactor = targetByReactor.get(reactor)
                    if (targetOfReactor === null) {
                        throw new Exception("MultipleGenerator found a reactor with an unknown target.")
                    } else if (! targetOfReactor.equalsIgnoreCase(target) ) {
                        reactor.setName(foreignReactorPrefix + reactor.getName())
                    }
                }
                
                // Next replace the target node in the new model 
                // with a new node with the name of that target
                // and "keepalive" set to true
                // FIXME: do something smarter than just creating 
                // a node with the appropriate name. Use properties
                // from the imported file somehow? 
                var newTarget = factory.createTarget()
                newTarget.setName(target)
                val configKeyValuePairs = factory.createKeyValuePairs
                val configKeyValuePair = factory.createKeyValuePair
                val trueElement = factory.createElement
                trueElement.setLiteral("true")
                configKeyValuePair.setName("keepalive")
                configKeyValuePair.setValue(trueElement)
                configKeyValuePairs.pairs.add(configKeyValuePair)
                newTarget.setConfig(configKeyValuePairs)
                
                EcoreUtil.replace(newModel.target, newTarget)
            }
            modelByTarget.put(target, newModel)
        }
        return modelByTarget;
    }
}
