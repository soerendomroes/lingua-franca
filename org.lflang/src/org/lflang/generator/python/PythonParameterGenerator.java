package org.lflang.generator.python;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collector;
import java.util.stream.Collectors;

import com.google.common.base.Objects;

import org.lflang.ASTUtils;
import org.lflang.generator.CodeBuilder;
import org.lflang.generator.GeneratorBase;
import org.lflang.generator.ParameterInstance;
import org.lflang.lf.ReactorDecl;
import org.lflang.lf.Value;
import org.lflang.lf.Assignment;
import org.lflang.lf.Parameter;


public class PythonParameterGenerator {
    /**
     * Generate Python code that instantiates and initializes parameters for a reactor 'decl'.
     * 
     * @param decl The reactor declaration
     * @return The generated code as a StringBuilder
     */
    public static String generatePythonInstantiations(ReactorDecl decl, PythonTypes types) {
        List<String> lines = new ArrayList<>();
        lines.add("# Define parameters and their default values");
        
        for (Parameter param : getAllParameters(decl)) {
            lines.add(generatePythonInstantiation(param, types));
        }
        // Handle parameters that are set in instantiation
        lines.addAll(List.of(
            "# Handle parameters that are set in instantiation",
            "self.__dict__.update(kwargs)",
            ""
        ));
        return String.join("\n", lines);
    }

    /**
     * Generate Python code that instantiates and initializes parameters for a reactor 'decl'.
     * 
     * @param paramName The name of the parameter
     * @param type The type of the parameter
     * @param initializer The initializer code for the parameter
     * @return The generated code
     */
    private static String generatePythonInstantiation(Parameter param, PythonTypes types) {
        String type = types.getTargetType(param).equals("PyObject*") ? null : 
                      types.getPythonType(ASTUtils.getInferredType(param));
        String paramName = param.getName();
        String initializer = generatePythonInitializer(param);
        if (type == null || type.equals("")) {
            return "self._"+paramName+" = "+initializer;
        }
        return "self._"+paramName+":"+type+" = "+initializer;
    }

    /**
     * Generate Python code getters for parameters of reactor 'decl'.
     * 
     * @param decl The reactor declaration
     * @return The generated code
     */
    public static String generatePythonGetters(ReactorDecl decl) {
        List<String> getters = new ArrayList<>();
        Set<String> paramNames = getAllParameters(decl).stream().map(
                                    it -> it.getName()
                                ).collect(Collectors.toSet());
        for (String paramName : paramNames) {
            getters.add(generatePythonGetter(paramName));
        }
        return String.join("\n", getters);
    }

    /**
     * Generate Python code getter for a parameter with name paramName.
     * 
     * @param paramName Name of the parameter
     * @return The generated code
     */
    private static String generatePythonGetter(String paramName) {
        return String.join("\n", 
            "@property",
            "def "+paramName+"(self):",
            "    return self._"+paramName+" # pylint: disable=no-member",
            ""
        );
    }

    /**
     * Return a list of all parameters of reactor 'decl'.
     * 
     * @param decl The reactor declaration
     * @return The list of all parameters of 'decl'
     */
    private static List<Parameter> getAllParameters(ReactorDecl decl) {
        return ASTUtils.allParameters(ASTUtils.toDefinition(decl));
    }

    /**
     * Create a Python list for parameter initialization in target code.
     * 
     * @param p The parameter to create initializers for
     * @return Initialization code
     */
    private static String generatePythonInitializer(Parameter p) {
        List<String> values = p.getInit().stream().map(PyUtil::getPythonTargetValue).collect(Collectors.toList());
        return values.size() > 1 ? "(" + String.join(", ", values) + ")" : values.get(0);
    }

    /**
     * Return a Python expression that can be used to initialize the specified
     * parameter instance. If the parameter initializer refers to other
     * parameters, then those parameter references are replaced with
     * accesses to the Python reactor instance class of the parents of 
     * those parameters.
     * 
     * @param p The parameter instance to create initializer for
     * @return Initialization code
     */
    public static String generatePythonInitializer(ParameterInstance p) {
        // Handle overrides in the instantiation.
        // In case there is more than one assignment to this parameter, we need to
        // find the last one.
        Assignment lastAssignment = getLastAssignment(p);
        List<String> list = new LinkedList<>();
        if (lastAssignment != null) {
            // The parameter has an assignment.
            // Right hand side can be a list. Collect the entries.
            for (Value value : lastAssignment.getRhs()) {
                if (value.getParameter() != null) {
                    // The parameter is being assigned a parameter value.
                    // Assume that parameter belongs to the parent's parent.
                    // This should have been checked by the validator.
                    list.add(PyUtil.reactorRef(p.getParent().getParent()) + "." + value.getParameter().getName());
                } else {
                    list.add(GeneratorBase.getTargetTime(value));
                }
            }
        } else {
            for (Value i : p.getParent().initialParameterValue(p.getDefinition())) {
                list.add(PyUtil.getPythonTargetValue(i));
            }
        }
        return list.size() > 1 ? "(" + String.join(", ", list) + ")" : list.get(0);
    }

    /**
     * Returns the last assignment to "p" if there is one, 
     * or null if there is no assignment to "p"
     * 
     * @param p The parameter instance to create initializer for
     * @return The last assignment of the parameter instance
     */
    private static Assignment getLastAssignment(ParameterInstance p) {
        Assignment lastAssignment = null;
        for (Assignment assignment : p.getParent().getDefinition().getParameters()) {
            if (Objects.equal(assignment.getLhs(), p.getDefinition())) {
                lastAssignment = assignment;
            }
        }
        return lastAssignment;
    }
}
