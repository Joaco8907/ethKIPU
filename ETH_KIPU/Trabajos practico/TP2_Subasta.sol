// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title : Practical work no. 2: Auction
/// @author : Gonzalez Joaquin

contract Auction {
    
    //Declaramos las variables de estado.(We declare the state variables)   
    address public owner;
    uint public endAuction;
    address public highestBidder;
    uint public bestOffer;
    bool public finished;
    
    // estas constantes se utilizaran para las require y determinar el precio inicial.
    //(These constants will be used for the requirements and to determine the initial price.)
    uint public constant INITIAL_MINIMUM = 10 ether; // parametro para precio inicial.(parameter for initial price)
    uint public constant MINIMUM_PERCENTAGE_INCREASE = 5; // Parametro para incremento en 5% al precio anterior. (Parameter for a 5% increase to the previous price.)
    uint public constant EXTENSION_TERM = 10 minutes; // parametro para extender el plazo.(parameter to extend the deadline.)
    uint public constant EXTENDABLE_MARGIN = 10 minutes; // parametro para extender el plazo en los ultimos 10 minutos.(parameter to extend the deadline by the last 10 minutes)

    // mapeo para los reembolsos de la subasta.(mapping for auction refunds.)
    mapping(address => uint) public offersEarrings;
    
    // Estructura que representa una oferta
    //(Structure that represents an offer)
    struct Offer {
        uint amount;
    }

    // Mapeo que asocia a cada dirección con una oferta
    mapping(address => Offer) public offers;

    //declaracion de evento para cuando surge una mejor oferta. anuncia al bidder, el amount, actualizacion de tiempo de finalizacion de subasta.
    //(Event statement for when a best offer emerges. Announces the bidder, the amount, and updates the auction end time.)
    event newBestOffer(address indexed bidder, uint _amount, uint newEnd);
    //declaracion de evento para cuando finalice la subasta. anuncia al winner y el amount.
    //(declaracion de evento para cuando finalice la subasta. anuncia al winner y el amount.)
    event auctionEnded(address indexed winner, uint amount);

    // utilizamos el constructor para inicializar al owner, establecer la duracion y establecer el amount inicial de la subasta.
    //(We use the constructor to initialize the owner, set the duration, and set the initial amount of the auction.) 
    constructor() {
        owner = msg.sender;
        endAuction = block.timestamp + 5 minutes;
        bestOffer = INITIAL_MINIMUM;
    }

    //este modificador va a impedir que el mismo owner pueda offer.
    //(This modifier will prevent the same owner from being able to offer.)
    modifier nonOwner(){
        require(msg.sender != owner, "El owner no puede offer");
        _;
    }
    
    // este modificador actua sobre la funcion oferta. determina si se puede offer o no tomando en cuenta el estado de la subasta y si block.timestamp es menor a endAuction.
    //(This modifier acts on the bid function. It determines whether an offer can be placed or not, taking into account the auction status and whether block.timestamp is less than endAuction.)
    modifier onlyBeforeFinishing () {
        require(!finished, "La subasta ya esta finished"); // requiere que no este finished.(requires that it not be finished)
        require(block.timestamp < endAuction, "La subasta termino"); // requiere que fin subasta sea mayor al momento de su creacion.(requires that the auction end be greater than the time of its creation.) 
        _;
    }

    // este modificador actua sobre la funcion endAuction. verifica si la subasta ya termino.
    //(This modifier acts on the endAuction function. It checks whether the auction has already ended.) 
    modifier onlyAfterFinishing () {
        // verifica si la subasta ya termino.(check if the auction has already ended.)
        require(block.timestamp >= endAuction,"La subasta aun esta activa");
        _;
    }

    address[] public bidderes;

    // esta funcion solo puede ser llamada desde afuera del contrato y es payable porque recibe ether. 
    //(This function can only be called from outside the contract and is payable because it receives ether.)
    function offer() external payable onlyBeforeFinishing nonOwner {
        // declaramos una variable local para almacenar el nuevo valor valido para offer conciderando que de ser mayor en un 5% al actual
        //(We declare a local variable to store the new valid value for offer, considering that if it is 5% greater than the current one)
        uint increaseRequired = (bestOffer * (100 + MINIMUM_PERCENTAGE_INCREASE)) / 100;
        // con la variable IcrementoRequerido Restringimos que el valor del ofertante sea mayor en un 5 al precio actual.
        //(With the variable IncrementoRequired we restrict the bidder's value to be 5 times greater than the current price.)
        require(msg.value >= increaseRequired, "La oferta debe superar al menos un 5% a la actual");
        //si es la primera vez que ofert este bidder, lo agrega al array.
        //(If this is the first time this bidder bids, add it to the array.)
        if(offersEarrings[msg.sender] == 0){
            bidderes.push(msg.sender);
        }

        // Actualizamos la oferta del remitente
        //(We updated the sender's offer)
        offers[msg.sender] = Offer({
            amount: msg.value
        });

        // guardamos el dinero del bidder anterior para que pueda retirlo si es superado por una nueva oferta.
        //(We keep the previous bidder's money so they can withdraw it if they are outbid by a new bid.)
        if (highestBidder != address(0)) {
            offersEarrings[highestBidder] += bestOffer;
        }
        // guardamos el nuevo valor del ofertante y su amount actualizando la duracion de tiempo de subastas.
        //(We save the new bidder value and its amount, updating the auction time duration.)
        highestBidder = msg.sender;
        bestOffer = msg.value;

        // extension del plazo si estamos en los ultimos 10 minutos antes de finalizar la subasta.
        //(extension of the deadline if we are in the last 10 minutes before the end of the auction.)
        if (endAuction - block.timestamp <= EXTENDABLE_MARGIN) {
            endAuction += EXTENSION_TERM;
        }

        // emitimos el evento con el nuevo valor de oferta y el amount actualizando la duracion del plazo
        //(We issue the event with the new bid value and the amount, updating the term duration.)
        emit newBestOffer(highestBidder, bestOffer, endAuction);

    }
    
     // Función para obtener la lista de ofertantes y sus montos
     //(Function to obtain the list of bidders and their amounts)
    function getOffers() public view returns (address[] memory, uint[] memory) {
        uint[] memory amount = new uint[](bidderes.length);
        for (uint i = 0; i < bidderes.length; i++) {
            amount[i] = offers[bidderes[i]].amount;
        }
        return (bidderes, amount);
    }
    //esta funcion se encargara de informar a los ofertantes cuanto tiempo queda antes de que finalice la subasta
    //(This function will inform bidders how much time is left before the auction ends.)
    function timeRemaining() public view returns (uint secondsRemaining) {
        if (block.timestamp > endAuction ) {
            return 0;
        } else {
            return endAuction - block.timestamp;
        }
    }

    //esta funcion que es llamada desde fuera del contrato. permite a los ofertantes superados en la subasta recupera su dinero. 
    //(This function, called from outside the contract, allows outbidders to recover their money.)
    function withdraw () external {
        //consulta cuanto dinero tiene pendiente de retirar el usuario que esta llamando a la funcion.
        //(check how much money the user calling the function has yet to withdraw.)
        uint amount = offersEarrings[msg.sender];
        // si el monto es menor a 0 le arrojara un mensaje que dira NADA PARA RETIRAR. Se revierte y no hace nada
        //(If the amount is less than 0, it will display a message saying NOTHING TO WITHDRAW. It is reversed and does nothing.)
        // esto evira transferencias innecesarias o maliciosas.
        //(This prevents unnecessary or malicious transfers.) 
        require(amount > 0,"Nada para withdraw");

        // ahora se pone en 0 el registro, para evitar reingreso.
        // (Now the record is reset to 0 to prevent re-entry.)
        offersEarrings[msg.sender]=0;

        // ahora usamos call{value:amount}("") para transferir Ether tambien se podria usar transfer(). pero con call evitamos errores por limites de gas.
        //(Now we use call{value:amount}("") to transfer Ether, we could also use transfer(). but with call we avoid errors due to gas limits.)
        //si el envio fallo, success sera false. si call fallo se revierte toda la op. y el usuario no pierde su derecho a retirara.
        //(If the transfer fails, the success will be false. If the call fails, the entire transaction is reversed, and the user does not lose their right to withdraw.)
        //esto es gracias a que seteamos/modificamos el monto a 0 en la linea anterior.
        //(This is because we set/modified the amount to 0 in the previous line.)
        (bool success, ) = payable(msg.sender).call{value: amount-((amount*2)/100)}("");
        // si el transferencia ha salido bien, entonces le devolvemos dinero de la mano del licitador que hizo la subastas y lo incrementamos en los pendientes con la suma de todas las ofertas."reteniendo el 2% para pago a mineros"
        //(If the transfer was successful, we will refund the money from the bidder who made the auctions and increase the outstanding amounts by the sum of all the bids."retaining 2% for payment to miners")
        require(success, "Fallo al enviar Ether");
    }

    //esta funcion se encarga de cerrar la subasta, anunciar al ganador mediante la emicion de un evento y enviar los fondos al propietario del contrato.
    //(This function is responsible for closing the auction, announcing the winner by issuing an event and sending the funds to the contract owner.)
    // trabaja con el modificador onlyAfterFinishing asegurandose que block.timestamp >= endAuction. y evita que alguien la finalice antes de tiempo. 
    //(works with the onlyAfterFinishing modifier ensuring that block.timestamp >= endAuction and prevents someone from ending it early.)
    function end_Auction() external onlyAfterFinishing {
        //Impide que la subasta se finalice mas de una vez.
        //(Prevents the auction from ending more than once.)
        require(!finished,"La subasta ya esta finished");
        // chequeamos que tengamos almenos una oferta. Ya que si no hay ninguna oferta no hay nada que tranferir ni ganador que declarar. 
        //(We check that we have at least one offer. If there isn't one, there's nothing to transfer and no winner to declare.)
        require(bestOffer > 0, "no se realizaron ofertas");
        
        // aqui cambiamos mediante un booleano el estado de la subasta. validando que la subasta a finalizado.
        //(Here we change the auction status using a Boolean, validating that the auction has ended.)
        // cambiamos el estado del contrato para que no se pueda volver a ejecutar la funcion.
        //(We change the state of the contract so that the function cannot be executed again.) 
        finished = true;

        // notificamos a la blockchain que la subasta termino, anunciamos al ganador y con que monto gano. 
        //(We notify the blockchain that the auction is over, announce the winner and the winning amount.)
        emit auctionEnded(highestBidder, bestOffer);

        // el propietario recauda los Ether usando call{value: amount...} para una tranferencia mas segura y flexible.
        //(The owner collects the Ether using call{value: amount...} for a more secure and flexible transfer.)
        (bool success, ) = payable(owner).call{value: bestOffer}("");
        // si el envio fallo por algun motivo, revierte toda la transaccion.
        //(If the shipment failed for any reason, reverse the entire transaction.)
        require(success, "Fallo al transferir al owner");
    }
    //Aqui finaliza el contrato.
    //(The contract ends here.)
}