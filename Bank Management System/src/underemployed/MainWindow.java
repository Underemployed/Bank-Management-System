package underemployed;
import javax.swing.*;
import java.awt.*;
public class MainWindow {

    private JFrame frame;

    public MainWindow(){
        initialize();
    }
    public void initialize(){
        frame = new JFrame();
        this.frame.setTitle("Database App");
        this.frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        this.frame.setSize(800,500);
        this.frame.setLocationRelativeTo(null);
        this.frame.setVisible(true);


        JPanel panel = new JPanel();
        Button b1 = new Button("First button");
        Button b2 = new Button("Second button");
        Button b3 = new Button("Third button");

        panel.add(b1);
        panel.add(b2);
        panel.add(b3);
        panel.setBackground(Color.RED);
        // panel.setPreferredSize(new Dimension(250,100)); set prefered size for panel so that it doesnt get affected by alignment
        panel.setLayout(new FlowLayout(FlowLayout.LEFT,10,5));
        frame.add(panel,BorderLayout.CENTER );
    }

}
