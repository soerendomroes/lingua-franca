/* Generator for UCLID5 target. */

package org.icyphy.generator

import java.io.File
import java.io.FileOutputStream
import java.util.ArrayList
import java.util.LinkedList
import java.util.regex.Pattern
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.icyphy.linguaFranca.Action
import org.icyphy.linguaFranca.VarRef


import static extension org.icyphy.ASTUtils.*

class UclidGenerator extends GeneratorBase {
    
    ////////////////////////////////////////////
    //// Private variables
    
    // Set of acceptable import targets includes only C.
    // val acceptableTargetSet = newHashSet('UCLID')

    // List of deferred assignments to perform in initialize_trigger_objects.
    // FIXME: Remove this and InitializeRemoteTriggersTable
    // var deferredInitialize = new LinkedList<InitializeRemoteTriggersTable>()
    
    // Place to collect code to initialize the trigger objects for all reactor instances.
    // var initializeTriggerObjects = new StringBuilder()

    // Place to collect code to go at the end of the __initialize_trigger_objects() function.
    // var initializeTriggerObjectsEnd = new StringBuilder()

    // The command to run the generated code if specified in the target directive.
    // var runCommand = new ArrayList<String>()

    // Place to collect shutdown action instances.
    // var shutdownActionInstances = new LinkedList<ActionInstance>()

    // Place to collect code to execute at the start of a time step.
    // var startTimeStep = new StringBuilder()
    
    /** Count of the number of is_present fields of the self struct that
     *  need to be reinitialized in __start_time_step().
     */
    // var startTimeStepIsPresentCount = 0
    
    /** Count of the number of token pointers that need to have their
     *  reference count decremented in __start_time_step().
     */
    // var startTimeStepTokens = 0

    // Place to collect code to initialize timers for all reactors.
    // protected var startTimers = new StringBuilder()
    // var startTimersCount = 0

    // For each reactor, we collect a set of input and parameter names.
    // var triggerCount = 0
    
    // Building strings that are shared across generator functions
    // FIXME: extract reactor and trigger info
    var ArrayList<String> reactorIDs
    var ArrayList<String> triggerIDs
    var ArrayList<String> reactorIDsWithStartups
    var ArrayList<String> specs
    
    // Path to the generated project directory
    var String projectPath
    var String srcGenPath
    
    // Concurrent regex pattern
    var concurrentPattern = Pattern.compile("^(concurrent)", Pattern.CASE_INSENSITIVE);
    
    // FIXME: find out if this is needed.
    new () {
        super()
        // set defaults
        this.targetCompiler = "uclid"
    }
    
    ////////////////////////////////////////////
    //// Private variables
    
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa,
        IGeneratorContext context) {
        
        // The following generates code needed by all the reactors.
        super.doGenerate(resource, fsa, context)
        
        
        // Create the src-gen directories if they don't yet exist.
        srcGenPath = directory + File.separator + "src-gen"
        var dir = new File(srcGenPath)
        if (!dir.exists()) dir.mkdirs()
        
        projectPath = srcGenPath + File.separator + filename
        dir = new File(projectPath)
        if (!dir.exists()) dir.mkdirs()
        
        // Collect string IDs from reactors and triggers
        reactorIDs = getReactorIDs()
        triggerIDs = getTriggerIDs()
        reactorIDsWithStartups = getReactorIDsWithStartups()
        
        // Collect specifications from the main preamble
        var defn = this.mainDef.reactorClass.toDefinition
        specs = new ArrayList<String>();
        for (p : defn.preambles ?: emptyList) {
            // No longer split by line
            // println(p.code.toText.split("\\r?\\n"))
            for (s : p.code.toText.split(";")) {
                specs.add(s)
            }
        }
        for (p : specs) {
            println(p)   
        }
        
        // Generate UCLID files for each specification
        // TODO: dependency analysis. See if the reactors
        // involved in the specification can be executed
        // concurrently.
        for (i : 0 ..< specs.length - 1) {
            // Create a directory for the spec
            var propPath = projectPath + File.separator + i
            dir = new File(propPath)
            if (!dir.exists()) dir.mkdirs()
            
            // Determine the appropriate semantics for this spec
            // Generate UCLID files for the specification
            var specIsConcurrent = isConcurrentSpec(specs.get(i))
            // TODO: use a separate parser to generate AST
            // for the spec to dynamically generate models
            var targetSpec = generateTargetSpec(this.targetCompiler, specs.get(i))
            println("Spec is " + targetSpec)
            
            if (specIsConcurrent) {
                generateConcurrentModel(propPath, targetSpec)
            } else {
                generateInterleavingModel(propPath, targetSpec)
            }
        }
    }
    
    /** Write the source code to file */
    protected def writeSourceCodeToFile(byte[] code, String path)
    {
        // Write the generated code to the output file.
        var fOut = new FileOutputStream(
            new File(path), false);
        fOut.write(code)
        fOut.close()
    }
    
    protected def ArrayList<String> getReactorIDs() {
        var reactorIDs = new ArrayList<String>();
        for (r : reactors) {
            reactorIDs.add(r.name)
        }
        return reactorIDs
    }
    
    // Returns a list of reactors that have startup actions
    protected def ArrayList<String> getReactorIDsWithStartups() {
        var reactorIDs = new ArrayList<String>();
        for (r : reactors) {
            for (rxn : r.getReactions()) {
                for (t : rxn.getTriggers) {
                    if (t.isStartup()) {
                        reactorIDs.add(r.name)
                    }
                }
            }
        }
        return reactorIDs
    }
    
    protected def ArrayList<String> getTriggerIDs() {
        var triggerIDs = new ArrayList<String>();
        for (r : reactors) {
            for (rxn : r.getReactions()) {
                for (t : rxn.getTriggers) {
                    if (t.isStartup()) {
                        triggerIDs.add(r.name + '_' + 'startup')
                    }
                    else if (t instanceof VarRef) {
                        triggerIDs.add(r.name + '_' + t.variable.name)
                    }
                }
            }
        }
        return triggerIDs
    }
    
    protected def ArrayList<String> getReactorTriggerIDs(String r) {
        var arr = new ArrayList<String>
        for (t : triggerIDs) {
            if (t.startsWith(r + '_')) {
                arr.add(t)
            }
        }
        return arr
    }
    
    protected def String getReactorInstanceID(String r) {
        return '__' + r.toLowerCase() + '__'
    }
    
    protected def String getVarIDfromTriggerID(String t) {
        return t.split("_", 2).get(1)
    }
    
    protected def String getReactorFromTrigger(String t) {
        return t.split('_').get(0)
    }
    
    protected def ArrayList<String> getStartupTriggerIDs() {
        var arr = new ArrayList<String>
        for (t : triggerIDs) {
            if (t.endsWith('_startup')) {
                arr.add(t)
            }
        }
        return arr
    }
    
    protected def generateInterleavingModel(String path, String spec) {
        generateCommonInt(path)        
        generatePQueueInt(path)
        generateSchedulerInt(path)
        generateReactorInt(path)
        generateMainInt(path, spec)
        generateDriverInt(path)
        
        println("Interleaving model generated for spec: " + spec)
    }
    
    protected def generateConcurrentModel(String path, String spec) {
        
        println("Concurrent model generated for spec: " + spec)
    }
    
    protected def boolean isConcurrentSpec(String spec) {
        return concurrentPattern.matcher(spec).find()
    }
    
    
    ////////////////////////////////////////////////////
    //// Spec translators for each verification platform
    
    protected def String generateTargetSpec(String target, String spec) {
        switch target {
            case 'uclid' : generateUclidSpec(spec)
            default : {
                throw new UnsupportedOperationException("Target " + target + " not supported.")
            }
        }
    }
    
    // TODO: Investigate whether an AST based solution is needed
    protected def String generateUclidSpec(String spec) {
        var li = spec.split(":")
        var pre = li.get(0).split(" ")
        var name = pre.get(pre.size - 1)
        var prop = li.get(1)
        return "property[LTL] " + name + ": " + "!F( " + prop + " );"
    }
    
    //////////////////////////////////////////////////
    //// Model generators under interleaving semantics.
    
    protected def generateCommonInt(String path){ 
        code = new StringBuilder()
        val commonFilename = "common.ucl"
        val reactorIdStr = String.join(', ', reactorIDs)
        val triggerIdStr = String.join(', ', triggerIDs)
        
        // Generate the common module
        pr('''
        module Common {
            // FILE_SPECIFIC
            type reactor_id_t = enum { «reactorIdStr», 
                                        NULL };
            type trigger_id_t = enum { «triggerIdStr», 
                                        NULL_NULL };
            type token_t      = integer; // To support "anytype"
        
            // COMMON
            type instant_t    = integer;
            type is_present_t = boolean;
        
            // Event type
            type event_t = {
                             instant_t,     // Tag
                             reactor_id_t,  // From
                             reactor_id_t,  // To
                             trigger_id_t,  // Trigger
                             token_t,       // Token
                             is_present_t   // Is_present
                           };
        
            define is_present(e : event_t) : boolean
            = (e != { -1, NULL, NULL, NULL_NULL, -1, false });
        }
         
        ''')
        
        // Generate simple queue
        pr('''
        module SimpleQueue {
            type * = Common.*;
        
            // A normal queue implementation using define
            type sq_data_t = event_t;
            type sq_content_t = { sq_data_t,
                                  sq_data_t,
                                  sq_data_t,
                                  sq_data_t,
                                  sq_data_t };
            type sq_t = { sq_content_t,
                          integer,  // HEAD
                          integer };  // TAIL
        
            const SIZE : integer = 5;
        
            define get(q : sq_content_t, i : integer) : sq_data_t
            = if (i == 1) then q._1 else
                (if (i == 2) then q._2 else
                    (if (i == 3) then q._3 else
                        (if (i == 4) then q._4 else
                            if (i == 5) then q._5 else
                                { -1, NULL, NULL, NULL_NULL, -1, false })));
        
            define set(q : sq_content_t, i : integer, v : sq_data_t) : sq_content_t
            = if (i == 1) then {v, q._2, q._3, q._4, q._5} else
                (if (i == 2) then {q._1, v, q._3, q._4, q._5} else
                    (if (i == 3) then {q._1, q._2, v, q._4, q._5} else
                        (if (i == 4) then {q._1, q._2, q._3, v, q._5} else (
                            if (i == 5) then {q._1, q._2, q._3, q._4, v} else
                                q))));
        
            define pushQ(q : sq_t, v : sq_data_t) : sq_t
            = { set(q._1, q._3, v),
                q._2,
                (if (q._3 + 1 > SIZE) then 0 else (q._3 + 1)) };
        
            define popQ(q : sq_t) : {sq_t, sq_data_t}
            = if (get(q._1, q._2) != { -1, NULL, NULL, NULL_NULL, -1, false })
              then  {{ set(q._1, q._2, { -1, NULL, NULL, NULL_NULL, -1, false }),
                        (if (q._2 + 1 > SIZE) then 0 else (q._2 + 1)),
                        q._3 }, 
                        get(q._1, q._2)}
              else {q, { -1, NULL, NULL, NULL_NULL, -1, false }};
        }
         
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), path + File.separator + commonFilename)
    }
    
    protected def generatePQueueInt(String path){
        code = new StringBuilder()
        val pqueueFilename = "pqueue.ucl"
        val startupTriggerIDs = getStartupTriggerIDs
        
        // FIXME: assign levels => reference to levels in LF.
        
        // Generate EventQ
        pr('''
        module EventQ
        {
            type * = Common.*;
        
            type op_t = enum { PUSH, POP };
            type index_t = integer;
            type count_t = integer;
            type data_t = event_t;
            type queue_t = {
                            data_t,
                            data_t,
                            data_t,
                            data_t,
                            data_t
                           };
        
            define get(q : queue_t, i : integer) : data_t
            = if (i == 1) then q._1 else
                (if (i == 2) then q._2 else
                    (if (i == 3) then q._3 else
                        (if (i == 4) then q._4 else
                            if (i == 5) then q._5 else
                                NULL_EVENT)));
        
            define set(q : queue_t, i : integer, v : data_t) : queue_t
            = if (i == 1) then {v, q._2, q._3, q._4, q._5} else
                (if (i == 2) then {q._1, v, q._3, q._4, q._5} else
                    (if (i == 3) then {q._1, q._2, v, q._4, q._5} else
                        (if (i == 4) then {q._1, q._2, q._3, v, q._5} else (
                            if (i == 5) then {q._1, q._2, q._3, q._4, v} else
                                q))));
        
            define inQ(q : queue_t, v : data_t) : boolean
            = (exists (i : index_t) ::
                (i >= 1 && i <= SIZE) && get(q, i) == v);
        
            define isNULL(d : data_t) : integer
            = if (d == NULL_EVENT) then 1 else 0;
        
            define countQ(q : queue_t) : integer
            = SIZE - (isNULL(q._1) + isNULL(q._2) + isNULL(q._3) + 
                        isNULL(q._4) + isNULL(q._5));
        
            const SIZE : integer = 5;
            
            var NULL_EVENT : data_t;
        
            input op : op_t;
            input data : data_t;
            output out : data_t; // Output from popQ()
        
            var contents : queue_t;
            var count : integer;
            var __idx__ : integer;
            var __done__ : boolean;
            var __min__ : data_t; 
        
            procedure pushQ()
                returns (
                    contentsP : queue_t,
                    countP : integer
                )
                modifies __idx__, __done__;
            {
                __idx__ = 1;
                __done__ = false;
                
                for (i : integer) in range(1, SIZE) {
                    if (get(contents, i) == NULL_EVENT &&
                        !__done__ &&
                        data != NULL_EVENT)
                    {
                        contentsP = set(contents, i, data);
                        countP = count + 1;
                        __done__ = true;
                    }
                }
        
                if (!__done__) {
                    contentsP = contents;
                    countP = count;
                }
            }
        
            procedure popQ()
                returns (
                    contentsP : queue_t,
                    countP : integer,
                    outP : data_t
                )
                modifies __min__, __idx__;
            {
                havoc __idx__;
                assume(forall (i : integer) ::
                    get(contents, i) != NULL_EVENT ==>
                    get(contents, __idx__)._1 <= get(contents, i)._1);
                assume(countQ(contents) > 0 ==> get(contents, __idx__) != NULL_EVENT);
        
                outP = get(contents, __idx__);
                contentsP = set(contents, __idx__, NULL_EVENT);
                if (outP == NULL_EVENT) {
                    countP = count;
                }
                else {
                    countP = count - 1;
                }
            }
        
            init {
                NULL_EVENT = { -1, NULL, NULL, NULL_NULL, -1, false };
                __idx__ = 0;
                __done__ = false;
        
                count = 0;
                contents = {
                            NULL_EVENT,
                            NULL_EVENT,
                            NULL_EVENT,
                            NULL_EVENT,
                            NULL_EVENT
                           };
            }
        
            next {
                case
                    (op == PUSH) : {
                        call (contents', count') = pushQ();
                    }
                    (op == POP) : {
                        call (contents', count', out') = popQ();
                    }
                esac
            }
        }
         
        ''')
        
        pr('''
        module ReactionQ
        {
            type * = Common.*;
        
            type op_t = enum { PUSH, POP };
            type index_t = integer;
            type count_t = integer;
            type data_t = event_t;
            type queue_t = {
                            data_t,
                            data_t,
                            data_t,
                            data_t,
                            data_t
                           };
        
            const SIZE : integer = 5;
            
            var NULL_EVENT : data_t;
        
            input op : op_t;
            input data : data_t;
            output out : data_t; // Output from popQ()
        
            var level : [trigger_id_t]integer;
            var contents : queue_t;
            var count : integer;
        
            var __idx__ : integer;
            var __done__ : boolean;
            var __min__ : data_t; 
        
            define get(q : queue_t, i : integer) : data_t
            = if (i == 1) then q._1 else
                (if (i == 2) then q._2 else
                    (if (i == 3) then q._3 else
                        (if (i == 4) then q._4 else
                            if (i == 5) then q._5 else
                                NULL_EVENT)));
        
            define set(q : queue_t, i : integer, v : data_t) : queue_t
            = if (i == 1) then {v, q._2, q._3, q._4, q._5} else
                (if (i == 2) then {q._1, v, q._3, q._4, q._5} else
                    (if (i == 3) then {q._1, q._2, v, q._4, q._5} else
                        (if (i == 4) then {q._1, q._2, q._3, v, q._5} else (
                            if (i == 5) then {q._1, q._2, q._3, q._4, v} else
                                q))));
        
            define inQ(q : queue_t, v : data_t) : boolean
            = (exists (i : index_t) ::
                (i >= 1 && i <= SIZE) && get(q, i) == v);
        
            define isNULL(d : data_t) : integer
            = if (d == NULL_EVENT) then 1 else 0;
        
            define countQ(q : queue_t) : integer
            = SIZE - (isNULL(q._1) + isNULL(q._2) + isNULL(q._3) + 
                        isNULL(q._4) + isNULL(q._5));
        
            procedure pushQ()
                returns (
                    contentsP : queue_t,
                    countP : integer
                )
                modifies __idx__, __done__;
            {
                __idx__ = 1;
                __done__ = false;
                
                for (i : integer) in range(1, SIZE) {
                    if (get(contents, i) == NULL_EVENT &&
                        !__done__ &&
                        data != NULL_EVENT)
                    {
                        contentsP = set(contents, i, data);
                        countP = count + 1;
                        __done__ = true;
                    }
                }
        
                if (!__done__) {
                    contentsP = contents;
                    countP = count;
                }
            }
        
            procedure popQ()
                returns (
                    contentsP : queue_t,
                    countP : integer,
                    outP : data_t
                )
                modifies __min__, __idx__;
            {
                havoc __idx__;
                assume(forall (i : integer) ::
                    get(contents, i) != NULL_EVENT ==>
                    level[get(contents, __idx__)._4] <= level[get(contents, i)._4]);
                assume(countQ(contents) > 0 ==> get(contents, __idx__) != NULL_EVENT);
        
                outP = get(contents, __idx__);
                contentsP = set(contents, __idx__, NULL_EVENT);
                if (outP == NULL_EVENT) {
                    countP = count;
                }
                else {
                    countP = count - 1;
                }
            }
        
            init {
                NULL_EVENT = { -1, NULL, NULL, NULL_NULL, -1, false };
                __idx__ = 0;
                __done__ = false;
        
                // File specific: levels
                level[Train_move] = 3; 
                level[Door_lock] = 3;
                level[Controller_startup] = 1;
                level[Controller_external] = 2;
        
                count = 0;
                contents = {
                            NULL_EVENT,
                            NULL_EVENT,
                            NULL_EVENT,
                            NULL_EVENT,
                            NULL_EVENT
                           };
        
                /********************************
                 * File specific: startup actions
                 ********************************/
                count = «startupTriggerIDs.length»;
                «FOR i : 0 ..< startupTriggerIDs.length»
                contents._«i + 1» = { 0, 
                                    «getReactorFromTrigger(startupTriggerIDs.get(i))», 
                                    «getReactorFromTrigger(startupTriggerIDs.get(i))»,
                                    «startupTriggerIDs.get(i)», 
                                    0, true };
                «ENDFOR»
            }
        
            next {
                case
                    (op == PUSH) : {
                        call (contents', count') = pushQ();
                        out' = NULL_EVENT;
                    }
                    (op == POP) : {
                        call (contents', count', out') = popQ();
                    }
                esac
            }
        }
        
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), path + File.separator + pqueueFilename)
    }
    
    protected def generateSchedulerInt(String path){
        code = new StringBuilder()
        val schedulerFilename = "scheduler.ucl"
        
        pr('''
        /**
         * Coordinates event passing between reactors and priority queues
         * and adjust the local clock.
         */
        ''')
        
        // Generate finalized table based on the number of reactions present
        // Currently the size is determined by the number of triggers.
        // FIXME: switch to reaction-based mechanism
        pr('''
        module Finalized {
            type final_tb_t = { 
                                «FOR i : 0 ..< triggerIDs.length»
                                    boolean«IF i != triggerIDs.length - 1»,«ENDIF»
                                «ENDFOR»
                              };
        }
         
        ''')
        
        pr('''
        module Scheduler {
            define * = Common.*; // Import is_present()
            type * = EventQ.*;
            const * = EventQ.*;
            type * = Finalized.*;
             
        ''')
        
        // FIXME: generate input/output variables
        pr('''
            «FOR r : reactorIDs»
                input «r»_to_S : event_t;
            «ENDFOR»
            «FOR r : reactorIDs»
                output S_to_«r» : event_t;
            «ENDFOR»
        ''')
        
        pr('''
            define has_available_event() : boolean
            = (
                «FOR i : 0 ..< reactorIDs.length»
                    «IF i != 0»||«ENDIF» is_present(«reactorIDs.get(i)»_to_S)
                «ENDFOR»
            );
        ''')
        
        pr('''
            define get(q : final_tb_t, i : integer) : boolean =
            «FOR i : 0 ..< triggerIDs.length»
                (if (i == «i + 1») then q._«i + 1» else
            «ENDFOR»
            false«FOR i : 0 ..< triggerIDs.length»)«ENDFOR»;
        ''')
        
        pr('''
            define set(q : final_tb_t, i : integer, v : boolean) : final_tb_t =
            «FOR i : 0 ..< triggerIDs.length»
                (if (i == «i + 1») then {
                    «FOR j : 0 ..< triggerIDs.length»
                        «IF j == i»v«ELSE»q._«j + 1»«ENDIF»«IF j != triggerIDs.length - 1», «ENDIF»
                    «ENDFOR»} else
            «ENDFOR»
            q«FOR i : 0 ..< triggerIDs.length»)«ENDFOR»;
        ''')
        
        pr('''
            // Set up finalized trigger table
            var finalized : final_tb_t;
            var f_counter : integer;
            
            «FOR i : 0 ..< triggerIDs.length»
            input finalize_«triggerIDs.get(i)» : boolean;
            «ENDFOR»
            «FOR i : 0 ..< reactorIDs.length»
            output final_to_«reactorIDs.get(i)» : final_tb_t;
            «ENDFOR»
        ''')
        
        pr('''
            // The "null" event
            var NULL_EVENT : event_t;
            
            // Event queue variables 
            // Both queues share these two fields for now.
            // If need be, separate them and create a NoOp operation for queues.
            var eq_op : op_t;
            var eq_data : data_t;
            var eq_out : data_t;
            
            // Reaction queue variables
            var rq_op : op_t;
            var rq_data : data_t;
            var rq_out : data_t;
            
            // Event queue and reaction queue
            instance event_q : EventQ(op : (eq_op), data : (eq_data), out : (eq_out));
            instance reaction_q : ReactionQ(op : (rq_op), data : (rq_data), out : (rq_out));
            
            // The current clock value
            var t : instant_t;
        ''')
        
        // FIXME: change how reaction is determined. Use an explicit
        // field in the event definition.
        pr('''
            define is_reaction(e : event_t) : boolean
            = if (e._1 == t) then true else false; 
            
            define get_event_present(e1 : event_t, e2 : event_t) : event_t
            = if (is_present(e1)) then e1 else e2;
            
            define get_event_dest(e : event_t, dest : reactor_id_t) : event_t
            = if (e._3 == dest) then e else NULL_EVENT;
        ''')
        
        pr('''
            /**
             * Load a non-empty input to push.
             */
            procedure push_event(e : event_t)
                returns (
                    eq_op : op_t,
                    eq_data : data_t,
                    rq_op : op_t,
                    rq_data : data_t
                )
            {
                if (is_reaction(e)) {
                    rq_op = PUSH;
                    rq_data = e;
        
                    // NoOp
                    eq_op = PUSH;
                    eq_data = NULL_EVENT;
                }
                else {
                    eq_op = PUSH;
                    eq_data = e;
        
                    // NoOp
                    rq_op = PUSH;
                    rq_data = NULL_EVENT;
                }
            }
        ''')
        
        pr('''
            procedure update_finalized_table()
                modifies finalized;
            {
                «FOR i : 0 ..< triggerIDs.length»
                if (finalize_«triggerIDs.get(i)») {
                    finalized = set(finalized, «i + 1», true);
                }
                «ENDFOR»
            }
        ''')
        
        
        pr('''
            init {
                NULL_EVENT = { -1, NULL, NULL, NULL_NULL, -1, false };
                t = 0;
        
                eq_op = PUSH;
                eq_data = NULL_EVENT;
        
                rq_op = PUSH;
                rq_data = NULL_EVENT;
        
                eq_out = NULL_EVENT;
                rq_out = NULL_EVENT;
        
                // File specific: init outputs
                «FOR i : 0 ..< reactorIDs.length»
                S_to_«reactorIDs.get(i)» = NULL_EVENT;
                «ENDFOR»
        
                // File specific: init finalization table
                finalized = {
                    «FOR i : 0 ..< triggerIDs.length»
                    false«IF i != triggerIDs.length - 1», «ENDIF»
                    «ENDFOR»
                };
                f_counter = 5;
                
                «FOR i : 0 ..< reactorIDs.length»
                final_to_«reactorIDs.get(i)» = finalized;
                «ENDFOR»
            }
        
        ''')
                
        pr('''
            next {
                // Push an incoming event
                if (has_available_event()) {
                    
                    // File specific: select an available event to push
                    case
                        «FOR i : 0 ..< reactorIDs.length»
                        (is_present(«reactorIDs.get(i)»_to_S)) : {
                            call (eq_op', eq_data', rq_op', rq_data')
                                = push_event(«reactorIDs.get(i)»_to_S);
                        }
                        «ENDFOR»
                    esac
                }
                // Pop an event from the queues
                else {
                    // At this point there are no more events 
                    // from both reactors, pop from queue
        
                    // Pop from reaction queue if it is not empty.
                    if (reaction_q.count > 0) {
                        rq_op' = POP;
                        rq_data' = NULL_EVENT;
        
                        eq_op' = PUSH; // Pushing a NULL_EVENT is similar to NoOp.
                        eq_data' = NULL_EVENT;
                    }
                    else {
                        rq_op' = PUSH;
                        rq_data' = NULL_EVENT;
        
                        eq_op' = POP;
                        eq_data' = NULL_EVENT;
                    }
                }
                
                // File specific: distribute events to appropriate reactors
                «FOR i : 0 ..< reactorIDs.length»
                S_to_«reactorIDs.get(i)»' = get_event_dest(
                                                get_event_present(rq_out', eq_out'),
                                                «reactorIDs.get(i)»
                                            );
                «ENDFOR»
        
                // Update finalized table based on a counter.
                if (f_counter == 0) {
                    call () = update_finalized_table();
                    f_counter' = 5;
                }
                else {
                    f_counter' = f_counter - 1;
                }
        
                «FOR i : 0 ..< reactorIDs.length»
                final_to_«reactorIDs.get(i)»' = finalized';
                «ENDFOR»
        
                // Update clock
                if (is_present(eq_out')) {
                    t' = eq_out'._1;
                }
        
                // Transition queues
                next(event_q);
                next(reaction_q);
            }
        }        
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), path + File.separator + schedulerFilename)
    }
    
    protected def generateReactorInt(String path) {
        code = new StringBuilder()
        val schedulerFilename = "reactor.ucl"
        var String rxn_postfix
        var ArrayList<String> rxn_triggerIDs
        
        pr('''
        /******************************
         * A list of reactor instances.
         * This section should be auto-
         * generated by the transpiler.
         *****************************/
        ''')
        
        for (r : reactors) {
            pr('''
                module Reactor_«r.name» {
            ''')
            pr('''
                // Import types and defines
                type * = SimpleQueue.*;
                define * = SimpleQueue.*;
                define * = Common.*;
                type * = Finalized.*;
            ''')
            
            // Declare state variables, inputs, outputs, actions
            // FIXME: expand to more state var types
            pr('''
                // State variables
                «FOR v : r.getStateVars»
                    var «v.name» : «IF v.getType.getId == 'int'»integer«ENDIF»;
                «ENDFOR»
                
                // Inputs
                «FOR v : r.getInputs»
                    var «v.name» : event_t;
                «ENDFOR»
                
                // Outputs
                «FOR v : r.getOutputs»
                    var «v.name» : event_t;
                «ENDFOR»
                
                // Actions
                «FOR v : r.getActions»
                    var «v.name» : event_t;
                «ENDFOR»
                «IF reactorIDsWithStartups.contains(r.name)»
                    var startup : event_t;
                «ENDIF»
            ''')
            
            pr('''
                /**********************
                 * Internal variables *
                 **********************/
            ''')
            pr('''
                // We need const tuple in UCLID
                var NULL_EVENT : event_t;
                
                // Time, scheduler input, scheduler output
                input t : integer;
                input __in__ : event_t;
                output __out__ : event_t;
                
                // Finalized table
                input finalized : final_tb_t;
                
                // File specific: LF inputs finalized entry
                // output finalize_Source_startup : boolean;
                «FOR t : getReactorTriggerIDs(r.name)»
                    output finalize_«t» : boolean;
                «ENDFOR»
                
                // A list of outbound events. Since one event is passed at a time,
                // We need a place to temporary store the events that are not sent yet.
                var outQ : sq_t;
                var __pop__ : { sq_t,
                                sq_data_t };
            ''')
            
            pr('''
                define all_inputs_empty () : boolean =
                «IF r.getInputs.length > 0»
                    «FOR i : 0 ..< r.getInputs.length»
                        !is_present(«r.getInputs.get(i).name») «IF i != r.getInputs.length - 1» && «ENDIF»
                    «ENDFOR»
                «ELSE»
                    true
                «ENDIF»;
                
            ''')
            
            /*
             * Generate reactions 
             */
            for (rxn : r.getReactions) {
                // Get reaction triggers
                rxn_triggerIDs = new ArrayList<String>
                // FIXME: with rxn.triggers, the IDE does not return error..
                for (t : rxn.getTriggers) {
                    if (t.isStartup()) {
                        rxn_triggerIDs.add('startup')
                    }
                    else if (t instanceof VarRef) {
                        rxn_triggerIDs.add(t.variable.name)
                    }
                }
                
                // Generate reaction postfix by concatenating trigger IDs
                // FIXME: generate from rxn_triggerIDs
                rxn_postfix = '''
                    «FOR t : rxn.getTriggers»«IF t.isStartup()»_startup«ELSEIF t instanceof VarRef»_«t.variable.name»«ENDIF»«ENDFOR»
                '''
                
                // Generate reaction declaration based on triggers
                pr('''
                    procedure rxn«rxn_postfix»()
                ''')
                
                // Declare all state variables modifiable
                // FIXME: check if this has unwanted side effects
                if (r.getStateVars.length > 0) {
                    pr('''
                        modifies «FOR i : 0 ..< r.getStateVars.length»«r.getStateVars.get(i).name»«IF i != r.getStateVars.length - 1»,«ENDIF»«ENDFOR»;
                    ''')
                }
                
                // Declare input variables to be modifiable
                for (t : rxn.getTriggers) {
                    if (t.isStartup()) pr('modifies startup;')
                    else if (t instanceof VarRef) pr('modifies ' + t.variable.name + ';')
                }
                
                // Declare internal variables to be modifiable
                pr('modifies outQ, __out__, __pop__;')
                
                // Generate finalized reaction table
                // FIXME: finalize reactions not triggers.
                // Currently, a single-trigger-based mechanism is in place.
                for (t : rxn.getTriggers) {
                    pr('''
                        modifies finalize_«r.name»_«IF t.isStartup()»startup«ELSEIF t instanceof VarRef»«t.variable.name»«ENDIF»;
                    ''')
                }
                
                pr('''
                    {
                        «rxn.getCode.getBody»

                        // Pop a value from outQ
                        // Handled in the reaction procedure for now since
                        // we need a sequential update to outQ.
                        __pop__ = popQ(outQ);
                        outQ = __pop__._1;
                        __out__ = __pop__._2;
                
                        // Clear inputs
                        // startup = NULL_EVENT;
                        «FOR t : rxn_triggerIDs»
                            «t» = NULL_EVENT;
                        «ENDFOR»
                
                        // Update finalized table
                        // finalize_Source_startup = true;
                        «FOR t : rxn_triggerIDs»
                            finalize_«r.name»_«t» = true;
                        «ENDFOR»
                    }
                ''')

            }
             
            pr('''
                init {
                    NULL_EVENT = { -1, NULL, NULL, NULL_NULL, -1, false };
                    __out__ = NULL_EVENT;
            
                    // "Setting" the input.
                    assume(__in__ == NULL_EVENT);
            
                    outQ = { { NULL_EVENT,
                             NULL_EVENT,
                             NULL_EVENT,
                             NULL_EVENT,
                             NULL_EVENT },
                             1, 1};
            
                    // File specific: init input/output/state variable
                    // startup = NULL_EVENT;
                    // State variables
                    «FOR v : r.getStateVars»
                        «v.name» = «IF v.getType.getId == 'int'»0«ELSE»0«ENDIF»;
                    «ENDFOR»
                    
                    // Inputs
                    «FOR v : r.getInputs»
                        «v.name» = NULL_EVENT;
                    «ENDFOR»
                    
                    // Outputs
                    «FOR v : r.getOutputs»
                        «v.name» = NULL_EVENT;
                    «ENDFOR»
                    
                    // Actions
                    «FOR v : r.getActions»
                        «v.name» = NULL_EVENT;
                    «ENDFOR»
                    «IF reactorIDsWithStartups.contains(r.name)»
                        startup = NULL_EVENT;
                    «ENDIF»
                    
                    // File specific: init all finalize_ flags here
                    «FOR t : getReactorTriggerIDs(r.name)»
                        finalize_«t» = false;
                    «ENDFOR»
                }
            ''')
            
            // Generate the next block
            pr('''
                next {
                    // File specific: load __in__ onto respective input variables
                    if (is_present(__in__)) {
                        case
                            «FOR t : getReactorTriggerIDs(r.name)»
                            (__in__._4 == «t») : {
                                «getVarIDfromTriggerID(t)»' = __in__;
                            }
                            «ENDFOR»
                        esac
            
                        // Reset finalize_ outputs at new logical time, which is
                        // denoted by a new finalized table
                        /*
                        if (finalized == {false, false, false}) {
                            finalize_Source_startup' = false;
                        }
                        */
                        if (finalized == {
                            «FOR i : 0 ..< triggerIDs.length»
                                false«IF i != triggerIDs.length - 1»,«ENDIF»
                            «ENDFOR»
                        }) {
                            «FOR t : getReactorTriggerIDs(r.name)»
                                finalize_«t»' = false;
                            «ENDFOR»
                        }
                    }
                    else {
                        // File specific: trigger reaction
                        case
                            «IF reactorIDsWithStartups.contains(r.name)»
                                (is_present(startup)) : {
                                    call () = rxn_startup();
                                }
                            «ENDIF»
                            «FOR v : r.getInputs»
                                (is_present(«v.name»)) : {
                                    call () = rxn_«v.name»();    
                                }
                            «ENDFOR» 
                            «FOR v : r.getActions»
                                (is_present(«v.name»)) : {
                                    call () = rxn_«v.name»();    
                                }
                            «ENDFOR» 
                            
                            (all_inputs_empty()) : {
                                __pop__' = popQ(outQ);
                                outQ' = __pop__'._1;
                                __out__' = __pop__'._2;
                            }
                        esac
                    }
                }
            ''')
            
            pr('}')
        }
        
        writeSourceCodeToFile(getCode().getBytes(), path + File.separator + schedulerFilename)
    }
    
    protected def generateMainInt(String path, String spec) {
        code = new StringBuilder()
        val schedulerFilename = "main.ucl"
        
        // Generate the init state of finalized reaction table
        val tableInit = '''
            «FOR i : 0 ..< triggerIDs.length»
                false«IF i != triggerIDs.length - 1»,«ENDIF»
            «ENDFOR»
        '''
        
        pr('''
        /********************************
         * The main module of the model *
         ********************************/
        ''')
        
        pr('''
        module main {
            type * = Common.*;
            type * = Finalized.*;
            
            // Reactors to scheduler
            «FOR r : reactorIDs»
            var «r»_to_S : event_t;
            «ENDFOR»
            
            // Scheduler to reactors
            «FOR r : reactorIDs»
            var S_to_«r» : event_t;
            «ENDFOR»
            
            // Finalized reaction indicator
            «FOR t : triggerIDs»
            var finalize_«t» : boolean;
            «ENDFOR»
            
            // Finalized reaction table
            «FOR r : reactorIDs»
            var final_to_«r» : final_tb_t;
            «ENDFOR»
            
            var NULL_EVENT : event_t;
        ''')
        
        pr('''
        instance scheduler : Scheduler(
            «FOR r : reactorIDs»
            «r»_to_S : («r»_to_S),
            «ENDFOR»
            «FOR r : reactorIDs»
            S_to_«r» : (S_to_«r»),
            «ENDFOR»
            «FOR t : triggerIDs»
            finalize_«t» : (finalize_«t»),
            «ENDFOR»
            «FOR i : 0 ..< reactorIDs.length»
            final_to_«reactorIDs.get(i)» : (final_to_«reactorIDs.get(i)»)«IF i != reactorIDs.length - 1»,«ENDIF»
            «ENDFOR»
        );
        ''')
        
        // Generate reactor instances
        // FIXME: move decl name collection to top-level doGenerate
        //        support multiple declarations of the same reactor
        val reactorDeclNames = new ArrayList<String>
        for (r : reactors) {
            for (i : this.instantiationGraph.getInstantiations(r)) {
                reactorDeclNames.add(i.name)
            }
        }
        for (i : 0 ..< reactorIDs.length) {
            var triggers = getReactorTriggerIDs(reactorIDs.get(i))
            pr('''
                instance «reactorDeclNames.get(i)» : Reactor_«reactorIDs.get(i)»(
                    t : (scheduler.t),
                    __in__ : (S_to_«reactorIDs.get(i)»),
                    __out__ : («reactorIDs.get(i)»_to_S),
                    finalized : (final_to_«reactorIDs.get(i)»),
                    «FOR j : 0 ..< triggers.length»
                    finalize_«triggers.get(j)» : (finalize_«triggers.get(j)»)«IF j != triggers.length - 1»,«ENDIF»
                    «ENDFOR»
                    );
            ''')
        }
        
        pr('''
        init {
            NULL_EVENT = { -1, NULL, NULL, NULL_NULL, -1, false };
            
            // Reactors to scheduler
            «FOR r : reactorIDs»
            «r»_to_S = NULL_EVENT;
            «ENDFOR»
            
            // Scheduler to reactors
            «FOR r : reactorIDs»
            S_to_«r» = NULL_EVENT;
            «ENDFOR»
            
            // Finalized reaction indicator
            «FOR t : triggerIDs»
            finalize_«t» = false;
            «ENDFOR»
            
            // Finalized reaction table
            «FOR r : reactorIDs»
            final_to_«r» = {
                «tableInit»
            };
            «ENDFOR»
        }
        ''')
        
        pr('''
        next {
            next(scheduler);
            «FOR i : 0 ..< reactorDeclNames.length»
            next(«reactorDeclNames.get(i)»);
            «ENDFOR»
        }
        ''')
        
        // Get properties from the main preamble
        /*
        var defn = this.mainDef.reactorClass.toDefinition
        for (p : defn.preambles ?: emptyList) {
            pr(p.code.toText)
        }
        */
        pr(spec)
        
        pr('''
        control {
            v = bmc(15);
            check;
            print_results;
            v.print_cex(
                scheduler.t,
                scheduler.event_q.contents, 
                scheduler.event_q.op,
                scheduler.event_q.data,
                scheduler.event_q.count,
                scheduler.reaction_q.contents, 
                scheduler.reaction_q.op,
                scheduler.reaction_q.data,
                scheduler.reaction_q.count,
                scheduler.eq_op,
                scheduler.eq_data,
                scheduler.eq_out,
                scheduler.rq_op,
                scheduler.rq_data,
                scheduler.rq_out,
                «FOR r : reactorIDs»
                scheduler.S_to_«r»,
                «ENDFOR»
                «FOR r : reactorIDs»
                scheduler.«r»_to_S,
                «ENDFOR»
                «FOR i : 0 ..< reactors.length»
                «reactorDeclNames.get(i)».__in__,
                «reactorDeclNames.get(i)».__out__,
                «FOR v : reactors.get(i).getStateVars»
                «reactorDeclNames.get(i)».«v.name»,
                «ENDFOR»
                «ENDFOR»
                scheduler.finalized
            );
        }
        ''')
        
        pr('}')
        
        writeSourceCodeToFile(getCode().getBytes(), path + File.separator + schedulerFilename)
    }
    
    protected def generateDriverInt(String path) {
        code = new StringBuilder()
        val schedulerFilename = "run.sh"
        
        pr('''
        uclid common.ucl pqueue.ucl scheduler.ucl reactor.ucl main.ucl
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), path + File.separator + schedulerFilename)
    }
    
    
    /////////////////////////////////////////////////
    //// Model generators under concurrent semantics.
    
    
    
    /////////////////////////////////////////////////
    //// Functions from generatorBase
    
    override generateDelayBody(Action action, VarRef port) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override generateForwardBody(Action action, VarRef port) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override generateDelayGeneric() {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override protected acceptableTargets() {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override supportsGenerics() {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override getTargetTimeType() {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override getTargetUndefinedType() {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override getTargetFixedSizeListType(String baseType, Integer size) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    override getTargetVariableSizeListType(String baseType) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
}