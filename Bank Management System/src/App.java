import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

public class App {
    public static void main(String[] args) throws Exception {
        // Database connection details
        String url = "jdbc:mysql://localhost:3306/";
        String username = "root";
        String password = "root";

        // Creating the database
        try {
            Connection connection = DriverManager.getConnection(url, username, password);
            System.out.println("Connected to the database!");
        } catch (SQLException e) {
            System.out.println("Failed to connect to the database.");
            e.printStackTrace();
        }
    }
}
