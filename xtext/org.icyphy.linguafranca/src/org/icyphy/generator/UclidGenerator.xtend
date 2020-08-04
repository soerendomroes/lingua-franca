/* Generator for UCLID5 target. */

package org.icyphy.generator

import java.io.File
import java.io.FileOutputStream
import java.math.BigInteger
import java.util.ArrayList
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.LinkedList
import java.util.regex.Pattern
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.icyphy.ASTUtils
import org.icyphy.InferredType
import org.icyphy.TimeValue
import org.icyphy.linguaFranca.Action
import org.icyphy.linguaFranca.ActionOrigin
import org.icyphy.linguaFranca.Code
import org.icyphy.linguaFranca.Import
import org.icyphy.linguaFranca.Input
import org.icyphy.linguaFranca.Instantiation
import org.icyphy.linguaFranca.LinguaFrancaFactory
import org.icyphy.linguaFranca.LinguaFrancaPackage
import org.icyphy.linguaFranca.Output
import org.icyphy.linguaFranca.Port
import org.icyphy.linguaFranca.Reaction
import org.icyphy.linguaFranca.Reactor
import org.icyphy.linguaFranca.StateVar
import org.icyphy.linguaFranca.TimeUnit
import org.icyphy.linguaFranca.Timer
import org.icyphy.linguaFranca.TriggerRef
import org.icyphy.linguaFranca.TypedVariable
import org.icyphy.linguaFranca.VarRef
import org.icyphy.linguaFranca.Variable
import java.io.BufferedReader
import java.io.FileReader

class UclidGenerator extends GeneratorBase {
    
    ////////////////////////////////////////////
    //// Private variables
    
    // Set of acceptable import targets includes only C.
    val acceptableTargetSet = newHashSet('UCLID')

    // List of deferred assignments to perform in initialize_trigger_objects.
    // FIXME: Remove this and InitializeRemoteTriggersTable
    var deferredInitialize = new LinkedList<InitializeRemoteTriggersTable>()
    
    // Place to collect code to initialize the trigger objects for all reactor instances.
    var initializeTriggerObjects = new StringBuilder()

    // Place to collect code to go at the end of the __initialize_trigger_objects() function.
    var initializeTriggerObjectsEnd = new StringBuilder()

    // The command to run the generated code if specified in the target directive.
    var runCommand = new ArrayList<String>()

    // Place to collect shutdown action instances.
    var shutdownActionInstances = new LinkedList<ActionInstance>()

    // Place to collect code to execute at the start of a time step.
    var startTimeStep = new StringBuilder()
    
    /** Count of the number of is_present fields of the self struct that
     *  need to be reinitialized in __start_time_step().
     */
    var startTimeStepIsPresentCount = 0
    
    /** Count of the number of token pointers that need to have their
     *  reference count decremented in __start_time_step().
     */
    var startTimeStepTokens = 0

    // Place to collect code to initialize timers for all reactors.
    protected var startTimers = new StringBuilder()
    var startTimersCount = 0

    // For each reactor, we collect a set of input and parameter names.
    var triggerCount = 0
    
    // Building strings that are shared across generator functions
    // FIXME: extract reactor and trigger info
    var ArrayList<String> reactorIDs
    var ArrayList<String> triggerIDs
    
    // Path to the generated project directory
    var String projectPath
    var String srcGenPath
    
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
        
        // Generate code for each reactor: reactor.ucl
        
        // Create the src-gen directories if they don't yet exist.
        srcGenPath = directory + File.separator + "src-gen"
        var dir = new File(srcGenPath)
        if (!dir.exists()) dir.mkdirs()

        projectPath = srcGenPath + File.separator + filename
        dir = new File(projectPath)
        if (!dir.exists()) dir.mkdirs()
                
        reactorIDs = getReactorIDs()
        triggerIDs = getTriggerIDs()
        
        /***************************
         ***   Generate files    ***
         ***************************/
        println("Generating common.ucl")
        generateCommon()
        
        println("Generating pqueue.ucl")
        generatePQueue()
        
        println("Generating scheduler.ucl")
        generateScheduler()
        
        println("Generating reactor.ucl")
        generateReactor()
        
        println("Generating main.ucl")
        generateMain()
        
        println("Generating run.sh")
        generateDriver()
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
        var reactor_ids = new ArrayList<String>();
        for (r : reactors) {
            reactor_ids.add(r.name)
        }
        return reactor_ids
    }
    
    protected def ArrayList<String> getTriggerIDs() {
        var trigger_ids = new ArrayList<String>();
        for (r : reactors) {
            for (rxn : r.getReactions()) {
                for (t : rxn.triggers) {
                    if (t.isStartup()) {
                        trigger_ids.add(r.name + '_' + 'startup')
                    }
                    else if (t instanceof VarRef) {
                        trigger_ids.add(r.name + '_' + t.variable.name)
                    }
                }
            }
        }
        return trigger_ids
    }
    
    protected def generateCommon(){
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
        
        writeSourceCodeToFile(getCode().getBytes(), projectPath + File.separator + commonFilename)
    }
    
    protected def generatePQueue(){
        code = new StringBuilder()
        val pqueueFilename = "pqueue.ucl"
        val startup_count = 0;
        
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
                level[Source_startup] = 0;
                level[A_in] = 1;
                level[B_in] = 1;
                «FOR r : reactorIDs»
                    level[«r»] = 1 // FIXME
                «ENDFOR»
        
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
                count = «startup_count»;
                «FOR i : 0 ..< triggerIDs.length»
                    «IF triggerIDs.get(i).contains('startup')»
                        contents._«i + 1» = { 0, 
                                        «getReactorFromTrigger(triggerIDs.get(i))», 
                                        «getReactorFromTrigger(triggerIDs.get(i))»,
                                        «triggerIDs.get(i)», 
                                        0, true }
                    «ENDIF»
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
        
        writeSourceCodeToFile(getCode().getBytes(), projectPath + File.separator + pqueueFilename)
    }
    
    protected def String getReactorFromTrigger(String t) {
        return t.split('_').get(0)
    }
    
    protected def generateScheduler(){
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
            «FOR r : reactors»
                input «r.name»_to_S : event_t
            «ENDFOR»
            «FOR r : reactors»
                output S_to_«r.name» : event_t
            «ENDFOR»
        ''')
        
        pr('''
            define has_available_event() : boolean
            = (
                «FOR i : 0 ..< reactors.length»
                    «IF i != 0»||«ENDIF» is_present(«reactors.get(i).name»_to_S)
                «ENDFOR»
            );
        ''')
        
        // Generate finalized table helper
        pr('''
            define get(q : final_tb_t, i : integer) : boolean
            = if (i == 1) then q._1 else
                (if (i == 2) then q._2 else
                    (if (i == 3) then q._3 else
                        false));
            
            define set(q : final_tb_t, i : integer, v : boolean) : final_tb_t
            = if (i == 1) then {v, q._2, q._3} else
                (if (i == 2) then {q._1, v, q._3} else
                    (if (i == 3) then {q._1, q._2, v} else
                         q));
             
        ''')
        
        pr('''
            // Finalized REACTION table
            var finalized : final_tb_t;
            var f_counter : integer;
            input finalize_Source_startup : boolean;
            input finalize_A_in : boolean;
            input finalize_B_in : boolean;
            output final_to_Source : final_tb_t;
            output final_to_A : final_tb_t;
            output final_to_B : final_tb_t;
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
        
        // FIXME: change how reaction is determined. Use an eplicit
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
        
        // FIXME: set a table of a parameterized size
        pr('''
            procedure update_finalized_table()
                modifies finalized;
            {
                if (finalize_Source_startup) {
                    finalized = set(finalized, 1, true);
                }
                if (finalize_A_in) {
                    finalized = set(finalized, 2, true);
                }
                if (finalize_B_in) {
                    finalized = set(finalized, 3, true);
                }
            }
        ''')
        
        // FIXME: init channel variables 
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
                S_to_Source = NULL_EVENT;
                S_to_A = NULL_EVENT;
                S_to_B = NULL_EVENT;
        
                // File specific: init finalization table
                finalized = { false, false, false };
                f_counter = 5;
                final_to_Source = finalized;
                final_to_A = finalized;
                final_to_B = finalized;
            }
        
        ''')
        
        // FIXME: generate this dynamically.
        pr('''
            next {
                // Push an incoming event
                if (has_available_event()) {
                    
                    // File specific: select an available event to push
                    case
                        (is_present(Source_to_S)) : {
                            call (eq_op', eq_data', rq_op', rq_data')
                                = push_event(Source_to_S);
                        }
                        (is_present(A_to_S)) : {
                            call (eq_op', eq_data', rq_op', rq_data')
                                = push_event(A_to_S);
                        }
                        (is_present(B_to_S)) : {
                            call (eq_op', eq_data', rq_op', rq_data')
                                = push_event(B_to_S);
                        }
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
                S_to_Source' = get_event_dest(
                                        get_event_present(rq_out', eq_out'),
                                        Source
                                       );
                S_to_A' = get_event_dest(
                                        get_event_present(rq_out', eq_out'),
                                        A
                                       );
                S_to_B' = get_event_dest(
                                        get_event_present(rq_out', eq_out'),
                                        B
                                       );
        
                // Update finalized table based on a counter.
                if (f_counter == 0) {
                    call () = update_finalized_table();
                    f_counter' = 5;
                }
                else {
                    f_counter' = f_counter - 1;
                }
        
                final_to_Source' = finalized';
                final_to_A' = finalized';
                final_to_B' = finalized';
        
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
        
        writeSourceCodeToFile(getCode().getBytes(), projectPath + File.separator + schedulerFilename)
    }
    
    protected def generateReactor() {
        code = new StringBuilder()
        val schedulerFilename = "reactor.ucl"
        
        pr('''
        /******************************
         * A list of reactor instances.
         * This section should be auto-
         * generated by the transpiler.
         *****************************/
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), projectPath + File.separator + schedulerFilename)
    }
    
    protected def generateMain() {
        code = new StringBuilder()
        val schedulerFilename = "main.ucl"
        
        pr('''
        /********************************
         * The main module of the model *
         ********************************/
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), projectPath + File.separator + schedulerFilename)
    }
    
    protected def generateDriver() {
        code = new StringBuilder()
        val schedulerFilename = "run.sh"
        
        pr('''
        uclid common.ucl pqueue.ucl scheduler.ucl reactor.ucl main.ucl
        ''')
        
        writeSourceCodeToFile(getCode().getBytes(), projectPath + File.separator + schedulerFilename)
    }
    
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