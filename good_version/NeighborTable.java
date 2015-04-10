import java.lang.*;
import java.util.Scanner;
import java.io.IOException;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;
import net.tinyos.tools.*;

public class NeighborTable implements MessageListener {
    private MoteIF moteIF;
/*    private List<NeighborTableMsg> messages=new ArrayList<NeighborTableMsg>(); */
    private NeighborTableMsg[] messages = new NeighborTableMsg[100];
    private int idx = 0;
    private int requestid = -1;
    
    public NeighborTable(MoteIF moteIF) {
        this.moteIF = moteIF;
        /* when NeighborTableMsg reach, invoke messsageReceived */
        this.moteIF.registerListener(new NeighborTableMsg(), this);
    }
    
    public void sendPackets() {
        NeighborTableMsg payload =  new NeighborTableMsg();
        try {
            System.out.println("Request Node" + requestid + "'s Neighbor Table");
            payload.set_nodeid(requestid);
            moteIF.send(0, payload);
        }
        catch (IOException exception) {
            System.err.println("Exception thrown when requesting to node" + requestid);
            System.err.println(exception);
        }
    }
    
    public void messageReceived(int to, Message message) {
        NeighborTableMsg msg = (NeighborTableMsg)message;
        /* add msg into a list until all message got then show neighbor table */
        /* this.messages.add(message); */
    	messages[idx++] = msg;
        if(msg.get_eof() == 1){
            showMessages();
            System.out.println("Request Again...");
            sendPackets();
        }
    }
    
    public void showMessages() {
        for(int i=0; i<idx; i++) {
            NeighborTableMsg msg = messages[i];
            System.out.println("NodeID: " + msg.get_nodeid() + ", Reliability: " + msg.get_reliability());
           /* messages.remove(msg); */  
        }
        System.out.println("");
	    idx = 0;
    }
    
    public static void usage() {
        System.err.println("Usage: NeighborTable [-comm <source>]");
    }
    
    public static void main(String[] args) throws Exception {
        String source = null;
        if (args.length == 2) {
            if(!args[0].equals("-comm")) {
                usage();
                System.exit(1);
            }
            source = args[1];
        }
        else if(args.length != 0) {
            usage();
            System.exit(1);
        }
        
        PhoenixSource phoenix;

        if(source == null) {
            phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
        }
        else {
            phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
        }
        
        MoteIF mif = new MoteIF(phoenix);
        NeighborTable serial = new NeighborTable(mif);
        
        Scanner input = new Scanner(System.in);
        System.out.println("Please Enter The Node ID You Want To Query: ");
        int temp = input.nextInt();
        requestid = temp;
        System.out.println("Please Hold On A Little Moment...");
        serial.sendPackets();
    }
}
