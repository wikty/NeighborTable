import java.lang.*
import java.io.Console;
import java.util.ArrayList;
import java.util.List;
import java.io.IOException;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;

public class NeighborTable implements MessageListener {
    private MoteIF moteIF;
    private List<NeighborTableMsg>messages=new ArrayList<>();
    
    public NeighborTable(MoteIF moteIF) {
        this.moteIF = moteIF;
        /* when NeighborTableMsg reach, invoke messsageReceived */
        this.moteIF.registerListener(new NeighborTableMsg(), this);
    }
    
    public void sendPackets(int nodeid) {
        SerialRequestMsg payload = new SerialRequestMsg();
        try {
            System.out.println("Request node" + nodeid + "'s neighbor table");
            payload.set_nodeid(nodeid);
            moteIF.send(0, payload);
        }
        catch (IOException exception) {
            System.err.println("Exception thrown when requesting to node" + nodeid);
            System.err.println(exception);
        }
    }
    
    public void messageReceived(int to, Message message) {
        NeighborTableMsg msg = (NeighborTableMsg)message;
        /* add msg into a list until all message got then show neighbor table */
        this.messages.add(message);
        if(message.getEof().equals(0)){
            showMessages();
        }
    }
    
    public void showMessages() {
        for(NeighborTableMsg msg:messages) {
            System.out.println("NodeID: " + msg.getNodeid() + ", Reliability: " + msg.getReliability());
            messages.remove(msg);   
        }
    }
    
    public static void usage() {
        System.err.println("Usage: NeighborTable [-comm <source>]");
    }
    
    public static void main(String[] args) throws Exception {
        String source = null;
        if (args.length == 2) {
            if(!args[0].equals("-comm")) {
                usage();
                System.exit();
            }
            source = args[1];
        }
        else if(args.length != 0) {
            usage();
            System.exit();
        }
        
        PhoenixSource phoenix;
        if(source == null) {
            phoenix = BuildSource.makePhoenix(PrintStreamMessager.err);
        }
        else {
            phoenix = BuildSource.makePhoneix(source, PrintStreamMessager.err);
        }
        
        MoteIF = mif = new MoteIF(phoenix);
        NeighborTable serial = new NeighborTable(mif);
        
        Console cons=System.console();
        String nodeid=cons.readLine("Please type NodeID: ");
        int temp=Integer.parseInt(nodeid);
        System.out.printlen("Please Hold On A Little Moment...");
        serial.sendPackets(temp);
        /*try {
            while (true) {
                serial.sendPackets(nodeid);
                
            }
        }
        catch (IOException exception) {
            System.err.println("System exit!");
            System.err.println(exception);
            System.exit();
        }
        */
    }
}
