package bank.management.system;

import java.sql.*;  

public class Conn{
    Connection c;
    Statement s;
    public Conn(){  
        try{  
            Class.forName("com.mysql.cj.jdbc.Driver");
            c = DriverManager.getConnection("jdbc:mysql:///bank", "root", "root");
            s = c.createStatement();
            System.out.println("Connection Successful");
            
        }catch(Exception e){ 
            System.out.println("Connection Failed,"+ e);
        }  
     }  
    // public static void main(String[] args) {
    //     new Conn();
    // }
}  

