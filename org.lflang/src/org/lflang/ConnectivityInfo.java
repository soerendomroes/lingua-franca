package org.lflang;

import java.math.BigInteger;

public class ConnectivityInfo {
    
    public boolean isConnection;
    public boolean isPhysical;
    public BigInteger delay;
    
    public ConnectivityInfo(boolean c, boolean p, BigInteger d) {
        isConnection    = c;
        isPhysical      = p;
        delay           = d;
    }
}