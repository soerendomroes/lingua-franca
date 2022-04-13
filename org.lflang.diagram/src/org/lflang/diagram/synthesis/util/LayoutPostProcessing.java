/*************
* Copyright (c) 2022, Kiel University.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice,
*    this list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the documentation
*    and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
* ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
* ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
***************/
package org.lflang.diagram.synthesis.util;

import java.util.Arrays;

import org.eclipse.elk.alg.layered.components.ComponentOrderingStrategy;
import org.eclipse.elk.alg.layered.options.CrossingMinimizationStrategy;
import org.eclipse.elk.alg.layered.options.CycleBreakingStrategy;
import org.eclipse.elk.alg.layered.options.GreedySwitchType;
import org.eclipse.elk.alg.layered.options.LayeredOptions;
import org.eclipse.elk.alg.layered.options.OrderingStrategy;
import org.eclipse.elk.core.options.CoreOptions;
import org.eclipse.elk.core.options.Direction;
import org.eclipse.elk.core.options.HierarchyHandling;
import org.lflang.diagram.synthesis.AbstractSynthesisExtensions;
import org.lflang.diagram.synthesis.LinguaFrancaSynthesis;

import de.cau.cs.kieler.klighd.SynthesisOption;
import de.cau.cs.kieler.klighd.kgraph.KNode;
import de.cau.cs.kieler.klighd.krendering.ViewSynthesisShared;
import de.cau.cs.kieler.klighd.syntheses.DiagramSyntheses;

/**
 * Set layout configuration options for the Lingua Franca diagram synthesis.
 * 
 * @author{Sören Domrös <sdo@informatik.uni-kiel.de>}
 */
@ViewSynthesisShared
public class LayoutPostProcessing extends AbstractSynthesisExtensions {
    
    // Related synthesis option
    
    public static final String GREEDY_CYCLE_BREAKING = "Greedy";
    public static final String MODEL_ORDER_CYCLE_BREAKING = "Model Order";

    public static final String CM_MO_OFF = "Off";
    public static final String CM_MO_NAE = "Nodes and Edges";
    public static final String CM_MO_PE = "Prefer Edges";

    public static final String CP_MO_OFF = "Off";
    public static final String CP_MO_CONSIDER = "Inside port side groups";
    public static final String CP_MO_STRICT = "On";

    public static final String MO_ALL = "Everything";
    public static final String MO_NO_ACTIONS = "Not for actions, timers";
    public static final String MO_NO_ACTIONS_SHUTDOWN = "Not for actions, timers, and shutdown";
    
    public static final SynthesisOption LAYOUT_CATEGORY = 
            SynthesisOption.createCategory("Layout", false).setCategory(LinguaFrancaSynthesis.APPEARANCE);
    public static final SynthesisOption CYCLE_BREAKING = 
            SynthesisOption.createChoiceOption("Cycle Breaking", Arrays.asList(GREEDY_CYCLE_BREAKING, MODEL_ORDER_CYCLE_BREAKING), GREEDY_CYCLE_BREAKING).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption CM_MODEL_ORDER = 
            SynthesisOption.createChoiceOption("Model Order Crossing Minimization", Arrays.asList(CM_MO_OFF, CM_MO_NAE, CM_MO_PE), CM_MO_OFF).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption SEPARATE_CONNECTED_COMPONENTS = 
            SynthesisOption.createCheckOption("Separate Connected Components", true).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption HIERARCHY_AWARE_LAYOUT = 
            SynthesisOption.createCheckOption("Hierarchy-aware layout", false).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption FORCE_NODE_ORDER = 
            SynthesisOption.createCheckOption("Force node model order", true).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption NO_CM = 
            SynthesisOption.createCheckOption("No crossing minimization", false).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption COMPONENT_ORDER = 
            SynthesisOption.createChoiceOption("Component Ordering", Arrays.asList(CP_MO_OFF, CP_MO_CONSIDER, CP_MO_STRICT), CP_MO_OFF).setCategory(LAYOUT_CATEGORY);
    public static final SynthesisOption NO_MODEL_ORDER = 
            SynthesisOption.createChoiceOption("Set model order for ", Arrays.asList(MO_ALL, MO_NO_ACTIONS, MO_NO_ACTIONS_SHUTDOWN), MO_NO_ACTIONS_SHUTDOWN).setCategory(LAYOUT_CATEGORY);
    
    
    public void configureMainReactor(KNode node) {
        configureReactor(node);
    }
    
    public void configureReactor(KNode node) {
        String moCM = (String) getObjectValue(CM_MODEL_ORDER);
        String componentOrder = (String) getObjectValue(COMPONENT_ORDER);
        String cycleBreakingStrategy = (String) getObjectValue(CYCLE_BREAKING);
        // Enable cycle breaking based on the option
        switch (cycleBreakingStrategy) {
            case MODEL_ORDER_CYCLE_BREAKING:
                // Enable strict model order cycle breaking. This requires all reactors to have a model order.
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CYCLE_BREAKING_STRATEGY, CycleBreakingStrategy.MODEL_ORDER);
                break;
            case GREEDY_CYCLE_BREAKING:
            default:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CYCLE_BREAKING_STRATEGY, CycleBreakingStrategy.GREEDY);
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, true);
                break;
        }
        
        // The layout direction of an reactor is always right
        DiagramSyntheses.setLayoutOption(node, CoreOptions.DIRECTION, Direction.RIGHT);

        // Set model order crossing minimization preprocessing.
        switch (moCM) {
            case CM_MO_NAE:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_STRATEGY, OrderingStrategy.NODES_AND_EDGES);
                break;
            case CM_MO_PE:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_STRATEGY, OrderingStrategy.PREFER_EDGES);
                break;
            case CM_MO_OFF:
            default:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_STRATEGY, OrderingStrategy.NONE);
                break;
        }

        // Set ordering of separate connected components. This is independent of the fact whether they exist or not.
        switch (componentOrder) {
            case CP_MO_STRICT:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_COMPONENTS, ComponentOrderingStrategy.FORCE_MODEL_ORDER);
                break;
            case CP_MO_CONSIDER:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_COMPONENTS, ComponentOrderingStrategy.INSIDE_PORT_SIDE_GROUPS);
                break;
            case CP_MO_OFF:
            default:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_COMPONENTS, ComponentOrderingStrategy.NONE);
                break;
        }
        
        // Separate connected components
        DiagramSyntheses.setLayoutOption(node, LayeredOptions.SEPARATE_CONNECTED_COMPONENTS, getBooleanValue(SEPARATE_CONNECTED_COMPONENTS));
        
        // Hierarchy aware laoyut
        DiagramSyntheses.setLayoutOption(node, LayeredOptions.HIERARCHY_HANDLING, getBooleanValue(HIERARCHY_AWARE_LAYOUT) ? HierarchyHandling.INCLUDE_CHILDREN : HierarchyHandling.INHERIT);
        
        // No crossing minimization means maximum control via the model order
        if (getBooleanValue(NO_CM)) {
            DiagramSyntheses.setLayoutOption(node, LayeredOptions.CROSSING_MINIMIZATION_STRATEGY, CrossingMinimizationStrategy.NONE);
            DiagramSyntheses.setLayoutOption(node, LayeredOptions.CROSSING_MINIMIZATION_GREEDY_SWITCH_TYPE, GreedySwitchType.OFF);            
        } else {
            // Default values LAYER_SWEEP, two-sided greedy switch
        }
        
        if (getBooleanValue(FORCE_NODE_ORDER)) {
            DiagramSyntheses.setLayoutOption(node, LayeredOptions.CROSSING_MINIMIZATION_FORCE_NODE_MODEL_ORDER, true);
            DiagramSyntheses.setLayoutOption(node, LayeredOptions.CROSSING_MINIMIZATION_GREEDY_SWITCH_TYPE, GreedySwitchType.OFF);
        } else {
            // Default values false and two-sided are used
        }
        
        // Sometimes it is usefull that a reactor has no model order but since we want cycle breaking,
        // we have to remove this
//        DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, true);
        
    }
    
    public void configureAction(KNode node) {
        String strategy = (String) getObjectValue(NO_MODEL_ORDER);
        switch (strategy) {
            case MO_NO_ACTIONS:
            case MO_NO_ACTIONS_SHUTDOWN:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, true);
                break;
            case MO_ALL:
            default:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, false);
                break;
        }
    }
    
    public void configureTimer(KNode node) {
        String strategy = (String) getObjectValue(NO_MODEL_ORDER);
        switch (strategy) {
            case MO_NO_ACTIONS:
            case MO_NO_ACTIONS_SHUTDOWN:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, true);
                break;
            case MO_ALL:
            default:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, false);
                break;
        }
    }
    
    public void configureStartUp(KNode node) {
        
    }
    
    public void configureShutDown(KNode node) {
        String strategy = (String) getObjectValue(NO_MODEL_ORDER);
        switch (strategy) {
            case MO_NO_ACTIONS_SHUTDOWN:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, true);
                break;
            case MO_ALL:
            case MO_NO_ACTIONS:
            default:
                DiagramSyntheses.setLayoutOption(node, LayeredOptions.CONSIDER_MODEL_ORDER_NO_MODEL_ORDER, false);
                break;
        }
    }
    
    public void configureReaction(KNode node) {
        
    }
    
    public void configureDummy(KNode node) {
        
    }

}
